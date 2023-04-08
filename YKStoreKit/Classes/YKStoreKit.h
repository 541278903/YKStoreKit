//
//  YKStoreKit.h
//  YKStoreKit
//
//  Created by edward on 2023/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol YKStoreKitPaySuccessProtocol <NSObject>

- (void)paySuccessWithStoreId:(NSString *)storeId
        transactionIdentifier:(NSString *)transactionIdentifier
        transactionReceiptStr:(NSString *)transactionReceiptStr
                     callBack:(void(^)(void))callBack;

@end

@protocol YKStoreKitDelegate <NSObject>

/// 错误回调
/// - Parameter error: 错误信息
- (void)error:(NSError *)error;

/// 日志回调
/// - Parameter message: 日志信息
- (void)log:(NSString *)message;

@end

@interface YKStoreKit : NSObject


/// 开始监听
+ (void)beginObserveWithProtocol:(id<YKStoreKitPaySuccessProtocol>)protocol;

/// 设置回调
+ (void)registWith:(id<YKStoreKitDelegate>)delegate;

/// 执行支付请求
/// - Parameter storeId: 内购Id
/// - Parameter params: 内购参数
+ (void)payWithStoreId:(NSString *)storeId params:(NSDictionary *)params;

@end

NS_ASSUME_NONNULL_END

