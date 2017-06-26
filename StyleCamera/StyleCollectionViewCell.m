//
//  StyleCollectionViewCell.m
//  StyleCamera
//
//  Created by realtouchapp on 2017/6/26.
//  Copyright © 2017年 realtouchapp. All rights reserved.
//

#import "StyleCollectionViewCell.h"

@implementation StyleCollectionViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)dealloc {
    [_styleImageView release];
    [super dealloc];
}

@end
