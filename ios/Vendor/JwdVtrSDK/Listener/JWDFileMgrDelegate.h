//
//  JWDFileMgrDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 文件管理委托协议
//

#import <Foundation/Foundation.h>
#import <JwdVtrSDK/JWDFileInfo.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 文件管理委托
 * 对应 Android 的 OnFileMgrListener
 */
@protocol JWDFileMgrDelegate <NSObject>

@optional

/**
 * 文件夹列表
 * @param dirs  文件夹名称列表
 * @param total 总数
 */
- (void)onFileDirs:(NSArray<NSString *> *)dirs total:(int)total;

/**
 * 文件夹下的文件列表
 * @param files 文件信息列表
 * @param dir   文件夹名称
 * @param total 总数
 */
- (void)onDirFiles:(NSArray<JWDFileInfo *> *)files dir:(NSString *)dir total:(int)total;

/**
 * 文件传输开始
 * @param fileName 文件名
 * @param fileLen  文件长度
 */
- (void)onTransStart:(NSString *)fileName fileLen:(long)fileLen;

/**
 * 文件实时传输数据
 * @param data     音频数据
 * @param fileName 对应的原始文件名
 */
- (void)onFileData:(NSData *)data fileName:(NSString *)fileName;

/**
 * 传输事件
 * @param event 1=传输完成, 2=传输中断, -1=传输出错
 */
- (void)onTransEvent:(int)event;

/**
 * 传输事件（含 CRC32，杰理方案新增）
 *
 * 杰理方案（feature-jli2）文件导入结束时，MCU 上报 MCU&OFF&CRC32，
 * 其中 CRC32 为 8 位十六进制字符串（如 FAFAFAFA），表示设备侧文件内容的
 * CRC32 校验值。SDK 解析后通过本回调随事件一起派发。
 *
 * 事件码语义与 onTransEvent: 完全一致：
 *   - event == 1（传输完成）时 crc32 为设备上报值（若设备未上报则为 nil）
 *   - event == 2 / -1 时 crc32 为 nil
 *
 * 实现本方法后，SDK 优先调用本方法（不再调用 onTransEvent:）；
 * 未实现时保持调用 onTransEvent:，旧代码无需任何改动。
 *
 * @param event 1=传输完成, 2=传输中断, -1=传输出错
 * @param crc32 设备侧文件 CRC32（8 位十六进制字符串大写，如 @"FAFAFAFA"）；
 *              事件非 1 或设备未上报时为 nil
 */
- (void)onTransEvent:(int)event crc32:(nullable NSString *)crc32;

/**
 * 恢复传输时断开连接
 * @param len      已传输长度
 * @param fileName 文件名
 */
- (void)onResumeBreak:(long)len fileName:(NSString *)fileName;

/**
 * 文件删除回调
 * @param code     1=成功, -1=失败
 * @param fileName 文件名
 */
- (void)onDeletedFile:(int)code fileName:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
