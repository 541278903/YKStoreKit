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
    NSDictionary *_params;
}
@end

@implementation YKStoreKitModel

- (NSString *)getStoreId
{
    return self->_storeId;
}

+ (YKStoreKitModel *)createWith:(NSString *)storeId params:(NSDictionary *)params
{
    YKStoreKitModel *modle = [[YKStoreKitModel alloc] init];
    modle->_storeId = storeId;
    modle->_params = params;
    return modle;
}

@end

@interface YKStoreKit () <SKPaymentTransactionObserver,SKProductsRequestDelegate>
{
    YKStoreKitModel *_currentModel;
    id<YKStoreKitDelegate> _delegate;
    id<YKStoreKitPaySuccessProtocol> _protocol;
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
        _instance->_currentModel = nil;
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

+ (void)payWithStoreId:(NSString *)storeId params:(NSDictionary *)params
{
    if ([YKStoreKit sharedInstance]->_currentModel != nil) {
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
        
        [YKStoreKit sharedInstance]->_currentModel = [YKStoreKitModel createWith:storeId params:params];
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

- (void)setModelToNull
{
    self->_currentModel = nil;
}

#pragma mark -=======
- (void)purchasedWithTransaction:(SKPaymentTransaction *)transaction
{
    //MARK: 验签回调
}

#pragma mark -=======
- (void)finishWithTransaction:(SKPaymentTransaction *)transaction
{
    //MARK: 结束支付
    NSString *storeId = [self->_currentModel getStoreId];
    self->_currentModel = nil;
    //TODO: 移除队列
    
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
       
        //MARK: 支付相关回调
        switch (obj.transactionState) {
            case SKPaymentTransactionStatePurchasing:
            {
                //正在交易
                [weakSelf log:@"正在交易"];
            }break;
            case SKPaymentTransactionStatePurchased:
            {
                //MARK: 完成交易
                [weakSelf log:@"完成交易"];
                
                id<YKStoreKitPaySuccessProtocol> protocol = [YKStoreKit sharedInstance]->_protocol;
                if (protocol && [protocol respondsToSelector:@selector(paySuccessWithStoreId:params:callBack:)]) {
                    [weakSelf purchasedWithTransaction:obj];
                }
                
            }break;
            case  SKPaymentTransactionStateFailed:
            {
                //MARK: 交易失败
                [weakSelf log:[NSString stringWithFormat:@"交易失败:%@",obj.error.localizedDescription]];
                [weakSelf error:obj.error.localizedDescription];
                [weakSelf finishWithTransaction:obj];
            }break;
            case SKPaymentTransactionStateRestored:
            {
                //MARK: 交易已被购买过
                [weakSelf log:@"交易已被购买过"];
                [weakSelf setModelToNull];
                [weakSelf error:@"交易已被购买过"];
            }break;
            case SKPaymentTransactionStateDeferred:
            {
                //交易被延期
                [weakSelf log:@"交易被延期"];
            }break;
                
            default:
                //其他状态
                [weakSelf log:@"其他状态"];
                break;
        }
    }];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *product = response.products;
    
    if([product count] == 0){
        self->_currentModel = nil;
        [self error:@"商品不存在"];
        return;
    }
    
    SKProduct *requestProduct = nil;
    for (SKProduct *pro in product) {
        
        [self log:[NSString stringWithFormat:@"\r\ndes:%@\r\nlocalizedTitle:%@\r\nlocalizedDescription:%@\r\nprice:%@\r\nproductIdentifier:%@",[pro description],[pro localizedTitle],[pro localizedDescription],[pro price],[pro productIdentifier]]];
        
        // 11.如果后台消费条目的ID与我这里需要请求的一样（用于确保订单的正确性）
        if([pro.productIdentifier isEqualToString:[self->_currentModel getStoreId]]){
            requestProduct = pro;
        }
    }
    
    // 12.发送购买请求
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:requestProduct];
    payment.quantity = 1;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}



@end
