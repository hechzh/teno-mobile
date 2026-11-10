import Foundation
import UIKit
import PhotosUI
import UniformTypeIdentifiers
import AVFoundation
import PDFKit
import Vision

@MainActor final class NativeImportCoordinator: NSObject, UIDocumentPickerDelegate, PHPickerViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let store: NativeStore, uploads: UploadQueue
    let presenter: () -> UIViewController?
    private var continuation: CheckedContinuation<JSONObject,Error>?
    private var owner = "", parent = ""
    private var atMs: Int64 = 0
    init(store: NativeStore, uploads: UploadQueue, presenter: @escaping () -> UIViewController?) {
        self.store = store; self.uploads = uploads; self.presenter = presenter
    }
    func open(source: String, parent: String = "", atMs: Int64 = 0) async throws -> JSONObject {
        guard continuation == nil, !store.scope.isEmpty, var view = presenter() else { throw RuntimeFailure("IMPORT_BUSY", "Sign in and close the current import before trying again.") }
        while let shown = view.presentedViewController { view = shown }
        let requestedOwner = store.scope
        if source == "camera" {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else { throw RuntimeFailure("CAMERA", "A camera is not available on this device.") }
            let granted = await AVCaptureDevice.requestAccess(for:.video)
            guard granted else { throw RuntimeFailure("CAMERA_PERMISSION", "Allow camera access in Settings.") }
        }
        guard requestedOwner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
        owner = requestedOwner; self.parent = parent; self.atMs = max(0,atMs)
        return try await withCheckedThrowingContinuation { result in
            continuation = result
            if source == "camera" {
                let camera = UIImagePickerController(); camera.sourceType = .camera; camera.delegate = self; view.present(camera,animated:true)
            } else if source == "photos" {
                var configuration = PHPickerConfiguration(); configuration.filter = .images; configuration.selectionLimit = parent.isEmpty ? 20 : 1
                let picker = PHPickerViewController(configuration:configuration); picker.delegate = self; view.present(picker,animated:true)
            } else {
                let picker = UIDocumentPickerViewController(forOpeningContentTypes:source == "audio" ? [.audio,.movie] : [.item],asCopy:false)
                picker.allowsMultipleSelection = true; picker.delegate = self; view.present(picker,animated:true)
            }
        }
    }
    func cancel() { continuation?.resume(returning:["items":[]]); continuation = nil }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { cancel() }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        finish(urls)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated:true)
        guard !results.isEmpty else { cancel(); return }
        Task {
            var copies: [URL] = []
            do {
                for result in results {
                    let file: URL = try await withCheckedThrowingContinuation { completion in
                        result.itemProvider.loadFileRepresentation(forTypeIdentifier:UTType.image.identifier) { url,error in
                            do {
                                if let error { throw error }
                                guard let url else { throw RuntimeFailure("IMPORT_FILE", "The photo could not be read.") }
                                let copy = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
                                try FileManager.default.copyItem(at:url,to:copy); completion.resume(returning:copy)
                            } catch { completion.resume(throwing:error) }
                        }
                    }
                    copies.append(file)
                }
                finish(copies, removeCopies:true)
            } catch {
                copies.forEach { try? FileManager.default.removeItem(at:$0) }
                continuation?.resume(throwing:error); continuation = nil
            }
        }
    }
    private func finish(_ urls: [URL], removeCopies: Bool = false) {
        guard let result = continuation else { return }; continuation = nil
        let scope = owner, parent = self.parent, position = atMs
        Task {
            defer { if removeCopies { urls.forEach { try? FileManager.default.removeItem(at:$0) } } }
            do { result.resume(returning:try await stage(urls, owner:scope, parent:parent, atMs:position)) }
            catch { result.resume(throwing:error) }
        }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated:true); cancel() }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey:Any]) {
        picker.dismiss(animated:true)
        do {
            guard let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality:0.92) else { throw RuntimeFailure("CAMERA", "The photo could not be saved.") }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Photo-" + UUID().uuidString + ".jpg")
            try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]); finish([url],removeCopies:true)
        } catch { continuation?.resume(throwing:error); continuation = nil }
    }
    static func kind(_ ext: String) -> String? {
        if ["wav","mp3","m4a","aac","flac","ogg","mp4","mov","3gp","webm"].contains(ext) { return "recording" }
        if ["png","jpg","jpeg","heic","heif"].contains(ext) { return "image" }
        if ["pdf","doc","docx","pptx","msg","txt","md"].contains(ext) { return "file" }
        if ext == "ics" { return "calendar" }
        return nil
    }
    func stage(_ urls: [URL], owner: String, parent: String = "", atMs: Int64 = 0, incoming: [String:JSONObject] = [:]) async throws -> JSONObject {
        guard owner == store.scope, !owner.isEmpty else { throw RuntimeFailure("ACCOUNT_CHANGED", "Sign in to the original account before importing.") }
        guard urls.count <= 20 else { throw RuntimeFailure("IMPORT_LIMIT", "Choose up to 20 files at a time.") }
        var created: [JSONObject] = [], results: [JSONObject] = []
        do {
            for source in urls {
                guard source.isFileURL, let kind = Self.kind(source.pathExtension.lowercased()) else { throw RuntimeFailure("IMPORT_FORMAT", "Choose a supported audio, video, document or PNG/JPEG file.") }
                let access = source.startAccessingSecurityScopedResource(); defer { if access { source.stopAccessingSecurityScopedResource() } }
                let size = try source.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                let limit = kind == "recording" ? 262144000 : kind == "image" ? 20000000 : ["txt","md"].contains(source.pathExtension.lowercased()) ? 2000000 : 15000000
                guard size > 0 && size <= limit else { throw RuntimeFailure("IMPORT_LIMIT", "This file is empty or exceeds the import limit.") }
                let original = incoming[source.path] ?? [:]
                let title = string(original["title"]).isEmpty ? source.lastPathComponent : string(original["title"])
                if kind == "calendar" {
                    let result = try await uploads.api.uploadSmall("/api/v1/events/import.ics",file:source,filename:title)
                    results.append(["type":"calendar","title":title,"count":(result["created_ids"] as? [String])?.count ?? 0]); continue
                }
                let ext = kind == "image" ? "jpg" : source.pathExtension.lowercased()
                let id = string(original["id"]).isEmpty ? UUID().uuidString.lowercased() : string(original["id"])
                if let existing = try? store.draft(id), FileManager.default.fileExists(atPath:string(existing["path"])) {
                    uploads.saved(id); results.append(existing); continue
                }
                var draft = try store.newDraft(title,ext:ext,id:id)
                let target = URL(fileURLWithPath:string(draft["path"]))
                created.append(draft)
                if kind == "image" {
                    guard let image = UIImage(contentsOfFile:source.path), image.size.width * image.size.height * image.scale * image.scale <= 25_000_000 else { throw RuntimeFailure("IMAGE_LIMIT", "Choose an image up to 25 megapixels.") }
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1
                    let pixels = CGSize(width:image.size.width * image.scale,height:image.size.height * image.scale)
                    let normalized = UIGraphicsImageRenderer(size:pixels,format:format).image { _ in image.draw(in:CGRect(origin:.zero,size:pixels)) }
                    guard let data = normalized.jpegData(compressionQuality:0.92), data.count <= 20000000 else { throw RuntimeFailure("IMAGE_LIMIT", "The image exceeds the import limit.") }
                    try data.write(to:target,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
                    let text = try await Task.detached(priority:.userInitiated) { () -> String in
                        let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate; request.recognitionLanguages = ["zh-Hans","en-US"]
                        if #available(iOS 16.0, *) { request.automaticallyDetectsLanguage = true }
                        try VNImageRequestHandler(url:target).perform([request])
                        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator:"\n")
                    }.value
                    draft["ocr_text"] = text
                } else {
                    let coordinator = NSFileCoordinator(); var coordinationError: NSError?, copyError: Error?
                    coordinator.coordinate(readingItemAt:source,options:.withoutChanges,error:&coordinationError) { file in
                        do { try FileManager.default.copyItem(at:file,to:target) } catch { copyError = error }
                    }
                    if let error = coordinationError { throw error }; if let error = copyError { throw error }
                    try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:target.path)
                }
                if kind == "recording" {
                    let duration = try await AVURLAsset(url:target).load(.duration).seconds
                    guard duration.isFinite && duration > 0 && duration <= 7200 else { throw RuntimeFailure("AUDIO_DURATION", "Choose valid audio or video up to 120 minutes.") }
                    draft["duration_ms"] = Int64(duration * 1000)
                } else if ext == "pdf" {
                    guard let document = PDFDocument(url:target), document.pageCount > 0 && document.pageCount <= 200 else { throw RuntimeFailure("DOCUMENT_LIMIT", "Choose a valid PDF up to 200 pages.") }
                }
                guard owner == store.scope else { throw RuntimeFailure("ACCOUNT_CHANGED", "The account changed.") }
                draft["kind"] = kind == "recording" ? "recording" : "file"
                draft["size"] = try target.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                draft["source"] = "import"; draft["filename"] = kind == "image" ? (title as NSString).deletingPathExtension + ".jpg" : title
                draft["parent_local_id"] = parent; draft["at_ms"] = atMs
                try store.save(draft); created[created.count-1] = draft; results.append(draft)
            }
        } catch {
            for item in created {
                try? FileManager.default.removeItem(at:URL(fileURLWithPath:string(item["path"])))
                if let directory = try? store.directory(owner) { try? FileManager.default.removeItem(at:directory.appendingPathComponent(string(item["id"]) + ".json")) }
            }
            throw error
        }
        created.forEach { uploads.saved(string($0["id"])) }
        return ["items":results.map { item -> JSONObject in var safe = item; safe.removeValue(forKey:"path"); return safe }]
    }
    private var pending: [JSONObject] { store.preferences.data(forKey:"incoming").flatMap { try? JSONSerialization.jsonObject(with:$0) as? [JSONObject] } ?? [] }
    func pendingItems() -> [JSONObject] { pending.map { ["id":string($0["id"]),"title":string($0["title"]),"size":$0["size"] ?? 0] } }
    func receiveExternal(_ url: URL) throws {
        guard pending.count < 20, url.isFileURL else { throw RuntimeFailure("IMPORT_LIMIT", "Choose up to 20 files at a time.") }
        let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
        guard size > 0 && size <= 262144000 else { throw RuntimeFailure("IMPORT_LIMIT", "This file is empty or exceeds the import limit.") }
        let folder = store.root.appendingPathComponent("incoming",isDirectory:true); try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let id = UUID().uuidString.lowercased(), ext = url.pathExtension.lowercased()
        guard ext.range(of:"^[a-z0-9]{1,8}$",options:.regularExpression) != nil else { throw RuntimeFailure("IMPORT_FORMAT", "Choose a supported file.") }
        let target = folder.appendingPathComponent(id + "." + ext)
        try FileManager.default.copyItem(at:url,to:target)
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:target.path)
        var items = pending; items.append(["id":id,"title":url.lastPathComponent,"size":size,"file":target.lastPathComponent])
        store.preferences.set(try jsonData(items),forKey:"incoming")
    }
    private func pendingURL(_ item: JSONObject) throws -> URL {
        let filename = string(item["file"])
        guard filename.range(of:"^[a-f0-9-]{36}\\.[a-z0-9]{1,8}$",options:.regularExpression) != nil else { throw RuntimeFailure("IMPORT_FILE", "Invalid pending import.") }
        return store.root.appendingPathComponent("incoming",isDirectory:true).appendingPathComponent(filename)
    }
    func discardPending() throws {
        for item in pending { try? FileManager.default.removeItem(at:pendingURL(item)) }
        store.preferences.removeObject(forKey:"incoming")
    }
    func acceptPending() async throws -> JSONObject {
        let items = pending, owner = store.scope
        let urls = try items.map { try pendingURL($0) }
        let entries = Dictionary(uniqueKeysWithValues:zip(urls.map(\.path),items))
        let result = try await stage(urls,owner:owner,incoming:entries)
        try discardPending(); return result
    }
}
