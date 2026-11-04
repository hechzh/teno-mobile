//
//  JWDFileBkDelegate.h
//  JwdVtrSDK
//
//  JWD VTR SDK - 录音文件标记 (BK) 委托协议
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 录音文件标记 (mark) 获取委托
 * 对应 Android 的 OnFileBkListener
 *
 * 对应协议:
 * - App → MCU: APP&BK&{dir}/{fileName}（注意 dir 与 fileName 之间为 "/" 分隔）
 * - MCU 推送: 通过音频 notify 通道持续发送二进制数据（UTF-8 文本，每行一个整数）
 * - MCU → App: MCU&BK&OK（传输结束）/ MCU&BK&ERR[&N]（失败）
 *
 * SDK 内部将累积的字节按 UTF-8 解码为字符串，按行（\r / \n / \r\n）分割并逐行
 * 解析为整数，通过 onFileBkReady:fileName:marks: 一次性回调。
 * 空行与无法解析为整数的行会被跳过（打 warn 日志，不抛错）。
 */
@protocol JWDFileBkDelegate <NSObject>

@optional

/**
 * 标记文件接收开始：SDK 已发送 APP&BK&{dir}/{fileName}，等待 MCU 从音频通道推送数据
 * @param dir      录音文件所在文件夹名
 * @param fileName 录音文件名
 */
- (void)onFileBkStart:(NSString *)dir fileName:(NSString *)fileName;

/**
 * 标记文件接收完成：SDK 已将所有音频帧累积并按 UTF-8 解码、按行解析为整数列表
 * @param dir      录音文件所在文件夹名
 * @param fileName 录音文件名
 * @param marks    解析后的整型标记集合，每行一个整数；空行 / 非整数行已跳过（可能为空数组）
 */
- (void)onFileBkReady:(NSString *)dir fileName:(NSString *)fileName marks:(NSArray<NSNumber *> *)marks;

/**
 * 标记文件接收失败
 * @param dir       录音文件所在文件夹名
 * @param fileName  录音文件名
 * @param errorCode MCU 返回的错误码：
 *                  0 - 通用错误（兼容旧版 MCU&BK&ERR，无错误码）
 *                  1 - 非空闲状态，不能获取标记
 *                  2 - 该文件没有标记
 *                  其他 - 未知错误码
 * @param reason    失败原因描述
 */
- (void)onFileBkError:(NSString *)dir fileName:(NSString *)fileName errorCode:(NSInteger)errorCode reason:(NSString *)reason;

@end

NS_ASSUME_NONNULL_END
