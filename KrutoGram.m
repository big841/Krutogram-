// KrutoGram — меню рядом с WhiteGram + настройка «как открывать меню»
// Сборка: xcrun -sdk iphoneos clang -arch arm64 -miphoneos-version-min=14.0 -dynamiclib -fobjc-arc \
//         -framework UIKit -framework Foundation -o KrutoGram.dylib KrutoGram.m
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kMode = @"KrutoGram.openMode"; // 0 = возле WhiteGram, 1 = зажатие «Помощь»
static NSInteger KGMode(void) { return [[NSUserDefaults standardUserDefaults] integerForKey:kMode]; }

static UIViewController *KGTop(void) {
    UIWindow *w = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes)
        if ([s isKindOfClass:UIWindowScene.class])
            for (UIWindow *x in ((UIWindowScene *)s).windows) if (x.isKeyWindow) w = x;
    UIViewController *vc = w.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

static void KGShowFunction(void);

static void KGShowMenu(void) {
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"KrutoGram" message:nil
                                                        preferredStyle:UIAlertControllerStyleActionSheet];
    [a addAction:[UIAlertAction actionWithTitle:@"Открывать меню KrutoGram" style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction *x) { KGShowFunction(); }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Закрыть" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top = KGTop();
    a.popoverPresentationController.sourceView = top.view;
    a.popoverPresentationController.sourceRect = CGRectMake(top.view.bounds.size.width / 2, 80, 1, 1);
    [top presentViewController:a animated:YES completion:nil];
}

// Первая функция: выбор способа открытия меню
static void KGShowFunction(void) {
    NSInteger m = KGMode();
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Открывать меню KrutoGram"
                                                               message:@"Выберите способ" preferredStyle:UIAlertControllerStyleActionSheet];
    NSArray *t = @[@"Возле меню WhiteGram", @"Зажатием кнопки «Помощь» в настройках"];
    for (NSInteger i = 0; i < 2; i++) {
        NSString *title = [NSString stringWithFormat:@"%@%@", (m == i ? @"✓ " : @""), t[i]];
        [a addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            [[NSUserDefaults standardUserDefaults] setInteger:i forKey:kMode];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"KGModeChanged" object:nil];
        }]];
    }
    [a addAction:[UIAlertAction actionWithTitle:@"Назад" style:UIAlertActionStyleCancel handler:nil]];
    UIViewController *top = KGTop();
    a.popoverPresentationController.sourceView = top.view;
    a.popoverPresentationController.sourceRect = CGRectMake(top.view.bounds.size.width / 2, 80, 1, 1);
    [top presentViewController:a animated:YES completion:nil];
}

// Поиск вью по тексту (Texture-ноды отдают текст через accessibilityLabel)
static UIView *KGFind(UIView *v, NSArray<NSString *> *names) {
    NSString *txt = [v isKindOfClass:UILabel.class] ? ((UILabel *)v).text : nil;
    NSString *acc = v.accessibilityLabel;
    for (NSString *n in names)
        if ([txt isEqualToString:n] || [acc isEqualToString:n] || [acc hasPrefix:[n stringByAppendingString:@","]]) return v;
    for (UIView *s in v.subviews) { UIView *r = KGFind(s, names); if (r) return r; }
    return nil;
}

static const void *kBtn = &kBtn, *kLP = &kLP;

static void KGInstall(UIViewController *vc) {
    UIView *root = vc.view;
    UIView *wg = KGFind(root, @[@"Whitegram", @"WhiteGram"]);
    if (!wg) return;
    UIView *row = wg.superview ?: wg;
    UIButton *btn = objc_getAssociatedObject(row, kBtn);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeSystem];
        [btn setTitle:@"KrutoGram" forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [btn addAction:[UIAction actionWithHandler:^(UIAction *x) { KGShowMenu(); }] forControlEvents:UIControlEventTouchUpInside];
        [row addSubview:btn];
        objc_setAssociatedObject(row, kBtn, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    CGRect f = wg.frame; // справа от надписи WhiteGram
    btn.frame = CGRectMake(CGRectGetMaxX(f) + 8, f.origin.y, 90, MAX(f.size.height, 28));
    btn.hidden = (KGMode() != 0);

    UIView *help = KGFind(root, @[@"Помощь", @"Help", @"Questions & Answers", @"Вопросы и ответы"]);
    if (help) {
        UIView *hrow = help.superview ?: help;
        if (!objc_getAssociatedObject(hrow, kLP)) {
            UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:nil action:nil];
            [lp addTarget:lp action:NSSelectorFromString(@"kg_fire:")];
            lp.minimumPressDuration = 0.6;
            lp.cancelsTouchesInView = NO;
            [hrow addGestureRecognizer:lp];
            objc_setAssociatedObject(hrow, kLP, lp, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

@implementation UILongPressGestureRecognizer (KG)
- (void)kg_fire:(UILongPressGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateBegan && KGMode() == 1) KGShowMenu();
}
@end

static void (*orig_appear)(UIViewController *, SEL, BOOL);
static void new_appear(UIViewController *self, SEL _cmd, BOOL animated) {
    orig_appear(self, _cmd, animated);
    __weak UIViewController *w = self;
    for (NSNumber *d in @[@0.3, @1.0, @2.0])
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(d.doubleValue * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (w.viewIfLoaded.window) KGInstall(w);
        });
}

__attribute__((constructor)) static void KGInit(void) {
    Method m = class_getInstanceMethod(UIViewController.class, @selector(viewDidAppear:));
    orig_appear = (void *)method_getImplementation(m);
    method_setImplementation(m, (IMP)new_appear);
    [[NSNotificationCenter defaultCenter] addObserverForName:@"KGModeChanged" object:nil queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(NSNotification *n) { KGInstall(KGTop()); }];
}
