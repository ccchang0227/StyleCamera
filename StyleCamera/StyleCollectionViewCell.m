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
    
    self.highlightMaskView.hidden = YES;
    
}

- (void)dealloc {
    [_styleImageView release];
    [_highlightMaskView release];
    [super dealloc];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    
    self.highlightMaskView.hidden = !highlighted;
    
}

@end
