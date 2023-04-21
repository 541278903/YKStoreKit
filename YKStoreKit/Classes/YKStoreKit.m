//
//  YKStoreKit.m
//  YKStoreKit
//
//  Created by edward on 2023/3/29.
//

#import "YKStoreKit.h"
#import <StoreKit/StoreKit.h>

@interface YKStoreKitModel : NSObject
{
    NSString * _storeId;
    NSString *_transactionIdentifier;
    NSString *_encodeStr;
}
@end

@implementation YKStoreKitModel

- (NSString *)getStoreId
{
    if (self->_storeId != nil) {
        return self->_storeId;
    } else {
        return @"";
    }
}

- (NSString *)getTransactionIdentifier
{
    if (self->_transactionIdentifier != nil) {
        return self->_transactionIdentifier;
    } else {
        return @"";
    }
}

- (void)setTransactionIdentifier:(NSString *)transactionIdentifier
{
    self->_transactionIdentifier = transactionIdentifier;
}

- (NSString *)getEncodeStr
{
    if (self->_encodeStr != nil) {
        return self->_encodeStr;
    } else {
        return @"";
    }
}

- (void)setEncodeStr:(NSString *)encodeStr
{
    self->_encodeStr = encodeStr;
}

/// 模型转字典
- (NSDictionary *)getThisModelToDic
{
    return @{@"storeId":[self getStoreId],@"transactionIdentifier":[self getTransactionIdentifier],@"encodeStr":[self getEncodeStr]};
}

/// 快速构造
/// - Parameters:
///   - storeId: 内购ID
///   - params: 内购参数
+ (YKStoreKitModel *)createWith:(NSString *)storeId transactionIdentifier:(NSString *)transactionIdentifier encodeStr:(NSString *)encodeStr
{
    YKStoreKitModel *modle = [[YKStoreKitModel alloc] init];
    modle->_storeId = storeId;
    modle->_transactionIdentifier = transactionIdentifier;
    modle->_encodeStr = encodeStr;
    return modle;
}

/// 字典转模型
/// - Parameter dic: 字典
+ (YKStoreKitModel *)modelWithDic:(NSDictionary *)dic
{
    if ([dic.allKeys containsObject:@"storeId"]) {
        
        YKStoreKitModel *modle = [[YKStoreKitModel alloc] init];
        modle->_storeId = dic[@"storeId"] ?: @"";
        if ([dic.allKeys containsObject:@"transactionIdentifier"]) {
            modle->_transactionIdentifier = dic[@"transactionIdentifier"] ?: @"";
        }
        
        if ([dic.allKeys containsObject:@"encodeStr"]) {
            modle->_encodeStr = dic[@"encodeStr"] ?: @"";
        }
        return modle;
    }
    return nil;
}

@end

@interface YKStoreKit () <SKPaymentTransactionObserver,SKProductsRequestDelegate>
{
    YKStoreKitModel *_storeModel;
    id<YKStoreKitDelegate> _delegate;
    id<YKStoreKitPaySuccessProtocol> _protocol;
    NSMutableArray *_cacheModels;
}

@end

@implementation YKStoreKit

static YKStoreKit *_instance;

+ (id)allocWithZone:(struct _NSZone *)zone
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });

    return _instance;
}

+ (instancetype)sharedInstance
{
    if (_instance == nil) {
        _instance = [[YKStoreKit alloc] init];
        _instance->_storeModel = nil;
    }

    return _instance;
}


/// 开始监听
+ (void)beginObserveWithProtocol:(id<YKStoreKitPaySuccessProtocol>)protocol;
{
    [YKStoreKit sharedInstance]->_protocol = protocol;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[YKStoreKit sharedInstance]];
}

+ (void)registWith:(id<YKStoreKitDelegate>)delegate
{
    [YKStoreKit sharedInstance]->_delegate = delegate;
}

+ (void)payWithStoreId:(NSString *)storeId
{
    if ([YKStoreKit sharedInstance]->_storeModel != nil && [[YKStoreKit sharedInstance]->_storeModel getStoreId] != nil) {
        //MARK: 上一笔交易未完成
        [[YKStoreKit sharedInstance] log:@"上一笔交易未完成"];
        [[YKStoreKit sharedInstance] error:@"上一笔交易未完成"];
        return;
    }
    
    void(^startRequest)(void) = ^(void){
        
        if ([YKStoreKit sharedInstance]->_protocol == nil) {
            [[YKStoreKit sharedInstance] log:@"未设置protocol"];
            [[YKStoreKit sharedInstance] error:@"未设置protocol"];
            return;
        }
        
        NSArray *product = [[NSArray alloc] initWithObjects:storeId,nil];
        NSSet *nsset = [NSSet setWithArray:product];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:nsset];
        request.delegate = [YKStoreKit sharedInstance];
        [request start];
    };
    
    NSArray *unfinishTransactions = [SKPaymentQueue defaultQueue].transactions;
    if (unfinishTransactions && unfinishTransactions.count > 0)  {
        //MARK: 🔥🔥🔥检测到未结束的订单，赶紧搞掉
        NSMutableArray *recs = [NSMutableArray array];
        for (SKPaymentTransaction *trans in unfinishTransactions) {
            if(unfinishTransactions.count == 1) {
                NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
                
                if (!receiptData) { // 八成卸载重装了
                    receiptData = trans.transactionReceipt;
                }
                if (receiptData) {
                    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
                    [recs addObject:encodeStr];
                }
            } else {
                if (trans.transactionReceipt) {
                    [recs addObject:[trans.transactionReceipt base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed]?:@""];
                }
            }
        }
        [[YKStoreKit sharedInstance] revarifyChargeOrderFromLocalWithTransition:unfinishTransactions receipts:recs completeBlock:^(NSError *error) {
            
            if (error) {
                // 错误了,那。。。。没办法。
                [[YKStoreKit sharedInstance] error:@"存在问题订单，请刷新重试"];
            } else {
                startRequest();
            }
        } slience:YES];
    } else {
        startRequest();
    }
}

#pragma mark -private
- (void)log:(NSString *)message
{
    //MARK: 日志回调
    id<YKStoreKitDelegate> delegate = self->_delegate;
    if (delegate && [delegate respondsToSelector:@selector(log:)]) {
        [delegate log:message];
    }
}

- (void)error:(NSString *)errorMessage
{
    //MARK: 错误回调
    id<YKStoreKitDelegate> delegate = self->_delegate;
    if (delegate && [delegate respondsToSelector:@selector(error:)]) {
        NSError *err = [NSError errorWithDomain:@"com.yk.storeKit" code:-1 userInfo:@{
            NSLocalizedDescriptionKey:errorMessage,
        }];
        [delegate error:err];
    }
}

- (void)setCurrentIDToNull
{
    self->_storeModel = nil;
}

#pragma mark -=======
- (void)purchasedWithTransaction:(SKPaymentTransaction *)transaction
{
    //MARK: 验签回调
    YKStoreKitModel *model = [self getCacheModelWithTransaction:transaction];
    id<YKStoreKitPaySuccessProtocol> protocol = self->_protocol;
    if (protocol && [protocol respondsToSelector:@selector(paySuccessWithStoreId:transactionIdentifier:transactionReceiptStr:callBack:)]) {
        __weak typeof(self) weakSelf = self;
        [protocol paySuccessWithStoreId:[model getStoreId] transactionIdentifier:[model getTransactionIdentifier] transactionReceiptStr:[model getEncodeStr] callBack:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf finishWithTransaction:transaction];
        }];
    }
}

- (YKStoreKitModel *)getCacheModelWithTransaction:(SKPaymentTransaction *)transaction
{
    NSMutableArray *datas = [[[NSUserDefaults standardUserDefaults] objectForKey:@"YKStoreKit_Cache_Model_UserDefaults_Key"]?:@[] mutableCopy];
    
    return nil;
}



/// 移除队列
/// - Parameter transaction: 支付信息
- (void)removeCacheWithTransaction:(SKPaymentTransaction *)transaction
{
    NSString *tStroeId = [NSString stringWithFormat:@"%@",@""];
    NSMutableArray *caches = [[[NSUserDefaults standardUserDefaults] objectForKey:@"YKStoreKit_Cache_Model_UserDefaults_Key"]?:@[] mutableCopy];
    [caches.copy enumerateObjectsUsingBlock:^(NSDictionary  *_Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.allKeys containsObject:@"storeId"]) {
            NSString *stordId = obj[@"storeId"]?:@"";
            if ([stordId isEqualToString:tStroeId]) {
                [caches removeObjectAtIndex:idx];
                *stop = YES;
            }
        }
    }];
    
    [[NSUserDefaults standardUserDefaults] setObject:[caches copy] forKey:@"YKStoreKit_Cache_Model_UserDefaults_Key"];
}


#pragma mark -=======
/// 结束支付
/// - Parameter transaction: 支付信息
- (void)finishWithTransaction:(SKPaymentTransaction *)transaction
{
    //MARK: 结束支付
    [self removeCacheWithTransaction:transaction];
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

#pragma mark -防丢订单
- (void)revarifyChargeOrderFromLocalWithTransition:(NSArray<SKPaymentTransaction *> *)transitions receipts:(NSArray<NSString *> *)receipts completeBlock:(void(^)(NSError *error))completeBlock slience:(BOOL)slience
{
    completeBlock(nil);
}

#pragma mark -代理
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    __weak typeof(self) weakSelf = self;
    [transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        //MARK: 支付相关回调
        switch (obj.transactionState) {
            case SKPaymentTransactionStatePurchasing:
            {
                //正在交易
                [strongSelf log:@"正在交易"];
            }break;
            case SKPaymentTransactionStatePurchased:
            {
                //MARK: 完成交易
                [strongSelf log:@"完成交易"];
                
                if (strongSelf->_storeModel == nil) {
                    //MARK: 杀掉了应用，直接验签
                    [strongSelf purchasedWithTransaction:obj];
                }else {
                    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
                    NSString *encodeStr = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
                    NSLog(@"%@",encodeStr);
                    
                    [strongSelf->_storeModel setEncodeStr:encodeStr];
                    [strongSelf->_storeModel setTransactionIdentifier:obj.transactionIdentifier];
                    
                    [strongSelf purchasedWithTransaction:obj];
                }
                
            }break;
            case  SKPaymentTransactionStateFailed:
            {
                //MARK: 交易失败
                [strongSelf log:[NSString stringWithFormat:@"交易失败:%@",obj.error.localizedDescription]];
                [strongSelf error:obj.error.localizedDescription];
                [strongSelf finishWithTransaction:obj];
            }break;
            case SKPaymentTransactionStateRestored:
            {
                //MARK: 交易已被购买过
                strongSelf->_storeModel = nil;
                [strongSelf log:@"交易已被购买过"];
                [strongSelf error:@"交易已被购买过"];
            }break;
            case SKPaymentTransactionStateDeferred:
            {
                //交易被延期
                [strongSelf log:@"交易被延期"];
            }break;
                
            default:
                //其他状态
                [strongSelf log:@"其他状态"];
                break;
        }
    }];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *product = response.products;
    
    if([product count] == 0){
        self->_storeModel = nil;
        [self error:@"商品不存在"];
        return;
    }
    
    SKProduct *requestProduct = nil;
    for (SKProduct *pro in product) {
        
        [self log:[NSString stringWithFormat:@"\r\n des:%@\r\n localizedTitle:%@\r\n localizedDescription:%@\r\n price:%@\r\n productIdentifier:%@",[pro description],[pro localizedTitle],[pro localizedDescription],[pro price],[pro productIdentifier]]];
        
        // 11.如果后台消费条目的ID与我这里需要请求的一样（用于确保订单的正确性）
        if([pro.productIdentifier isEqualToString:[self->_storeModel getStoreId]]){
            requestProduct = pro;
            
            
        }
    }
    
    //MARK: 保存订单到缓存
    
    
    // 12.发送购买请求
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:requestProduct];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}



@end
