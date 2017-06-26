//
//  BaseViewController.m
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "BaseViewController.h"

@interface BaseViewController ()

@end

@implementation BaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
                   actions:(UIAlertAction *)actions, ... {
    
    NSMutableArray *actionsArray = [NSMutableArray array];
    if (actions) {
        UIAlertAction *action = actions;
        [actionsArray addObject:action];
        
        va_list args;
        va_start(args, actions);
        while ((action = va_arg(args, UIAlertAction *))) {
            if (action && [action isKindOfClass:[UIAlertAction class]]) {
                [actionsArray addObject:action];
            }
        }
        va_end(args);
    }
    
    if (actionsArray.count > 0) {
        [self showAlertWithTitle:title message:message actionsArray:actionsArray];
    }
}

- (void)showAlertWithTitle:(NSString *)title
                   message:(NSString *)message
              actionsArray:(NSArray<UIAlertAction *> *)actionsArray {
    if (![UIAlertController class]) {
        return;
    }
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title
                                                                             message:message
                                                                      preferredStyle:UIAlertControllerStyleAlert];
    for (UIAlertAction *action in actionsArray) {
        [alertController addAction:action];
    }
    
    [self presentViewController:alertController animated:YES completion:nil];
}

@end
