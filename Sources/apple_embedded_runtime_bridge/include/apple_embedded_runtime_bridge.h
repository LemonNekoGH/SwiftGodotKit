#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class GDTView;

@interface GDTApplicationDelegate : NSObject <UIApplicationDelegate>
@end

@interface GDTViewController : UIViewController
@property(nonatomic, readonly, strong) GDTView *godotView;
@end

@interface GDTAppDelegateService : NSObject <UIApplicationDelegate>
@property(strong, class, nonatomic) GDTViewController *viewController;
@end

@interface GDTView : UIView
- (void)startRendering;
- (void)stopRendering;
@end

FOUNDATION_EXPORT UIViewController * _Nullable SGKCreateAndRegisterGodotViewController(void);
FOUNDATION_EXPORT void SGKStartGodotViewRendering(UIViewController *controller);
FOUNDATION_EXPORT void SGKStopGodotViewRendering(UIViewController *controller);

NS_ASSUME_NONNULL_END
