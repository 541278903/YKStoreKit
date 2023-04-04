//
//  YKStoreKit.h
//  YKStoreKit
//
//  Created by edward on 2023/3/29.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface YKStoreKit : NSObject


/// 执行
+ (void)regist;

/// 执行支付请求
/// - Parameter storeId: 内购Id
+ (void)payWithStoreId:(NSString *)storeId;

@end

NS_ASSUME_NONNULL_END

