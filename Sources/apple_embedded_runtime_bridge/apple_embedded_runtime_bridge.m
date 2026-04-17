#import "apple_embedded_runtime_bridge.h"

UIViewController *SGKCreateAndRegisterGodotViewController(void) {
    GDTViewController *controller = [GDTViewController new];
    GDTAppDelegateService.viewController = controller;
    return controller;
}

void SGKStartGodotViewRendering(UIViewController *controller) {
    if ([controller isKindOfClass:[GDTViewController class]]) {
        [((GDTViewController *)controller).godotView startRendering];
    }
}

void SGKStopGodotViewRendering(UIViewController *controller) {
    if ([controller isKindOfClass:[GDTViewController class]]) {
        [((GDTViewController *)controller).godotView stopRendering];
    }
}
