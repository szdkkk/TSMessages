//
//  TSMessageView.m
//  Toursprung
//
//  Created by Felix Krause on 24.08.12.
//  Copyright (c) 2012 Toursprung. All rights reserved.
//

#import "TSMessageView.h"
#import "UIColor+MLColorAdditions.h"

#define TSMessageViewPadding 15.0

#define TSDesignFileName @"design.json"

static NSDictionary *notificationDesign;

@interface TSMessageView ()

@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSString *content;
@property (nonatomic, strong) UIViewController *viewController;

/** Internal properties needed to resize the view on device rotation properly */
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) UIImageView *backgroundImageView;

@property (nonatomic, strong) UISwipeGestureRecognizer *gestureRec;
@property (nonatomic, strong) UITapGestureRecognizer *tapRec;

@property (nonatomic, assign) CGFloat textSpaceLeft;


- (CGFloat)updateHeightOfMessageView;
- (void)layoutSubviews;

@end


@implementation TSMessageView

- (id)initWithTitle:(NSString *)title
        withContent:(NSString *)content
           withType:(notificationType)notificationType
       withDuration:(CGFloat)duration
   inViewController:(UIViewController *)viewController
{
    if (!notificationDesign)
    {
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:TSDesignFileName];
        notificationDesign = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                             options:kNilOptions
                                                               error:nil];
    }
    
    if ((self = [self init]))
    {
        _title = title;
        _content = content;
        _duration = duration;
        _viewController = viewController;
        
        CGFloat screenWidth = self.viewController.view.frame.size.width;
        NSDictionary *current;
        NSString *currentString;
        switch (notificationType)
        {
            case kNotificationMessage:
            {
                currentString = @"message";
                break;
            }
            case kNotificationError:
            {
                currentString = @"error";
                break;
            }
            case kNotificationSuccessful:
            {
                currentString = @"success";
                break;
            }
            case kNotificationWarning:
            {
                currentString = @"warning";
                break;
            }
                
            default:
                break;
        }
        
        current = [notificationDesign valueForKey:currentString];
        
        self.alpha = 0.0;
        
        UIImage *image;
        if ([current valueForKey:@"imageName"])
        {
            image = [UIImage imageNamed:[current valueForKey:@"imageName"]];
        }
        
        // add background image here
        UIImage *backgroundImage = [[UIImage imageNamed:[current valueForKey:@"backgroundImageName"]] stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];
        _backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
        self.backgroundImageView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
        [self addSubview:self.backgroundImageView];
        
        UIColor *fontColor = [UIColor colorWithHexString:[current valueForKey:@"textColor"]
                                                   alpha:1.0];
        
        
        self.textSpaceLeft = 2 * TSMessageViewPadding;
        if (image) self.textSpaceLeft += image.size.width + 2 * TSMessageViewPadding;
        
        // Set up title label
        _titleLabel = [[UILabel alloc] init];
        [self.titleLabel setText:title];
        [self.titleLabel setTextColor:fontColor];
        [self.titleLabel setBackgroundColor:[UIColor clearColor]];
        [self.titleLabel setFont:[UIFont boldSystemFontOfSize:[[current valueForKey:@"titleFontSize"] floatValue]]];
        [self.titleLabel setShadowColor:[UIColor colorWithHexString:[current valueForKey:@"shadowColor"] alpha:1.0]];
        [self.titleLabel setShadowOffset:CGSizeMake([[current valueForKey:@"shadowOffsetX"] floatValue],
                                                    [[current valueForKey:@"shadowOffsetY"] floatValue])];
        self.titleLabel.numberOfLines = 0;
        self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:self.titleLabel];
        
        // Set up content label (if set)
        if ([content length])
        {
            _contentLabel = [[UILabel alloc] init];
            [self.contentLabel setText:content];
            [self.contentLabel setTextColor:fontColor];
            [self.contentLabel setBackgroundColor:[UIColor clearColor]];
            [self.contentLabel setFont:[UIFont systemFontOfSize:[[current valueForKey:@"contentFontSize"] floatValue]]];
            [self.contentLabel setShadowColor:self.titleLabel.shadowColor];
            [self.contentLabel setShadowOffset:self.titleLabel.shadowOffset];
            self.contentLabel.lineBreakMode = self.titleLabel.lineBreakMode;
            self.contentLabel.numberOfLines = 0;
            
            [self addSubview:self.contentLabel];
        }
        
        if (image)
        {
            _iconImageView = [[UIImageView alloc] initWithImage:image];
            self.iconImageView.frame = CGRectMake(TSMessageViewPadding * 2,
                                                  TSMessageViewPadding,
                                                  image.size.width,
                                                  image.size.height);
            [self addSubview:self.iconImageView];
        }
        
        // Add a border on the bottom
        _borderView = [[UIView alloc] initWithFrame:CGRectMake(0.0,
                                                               0.0, // will be set later
                                                               screenWidth,
                                                               [[current valueForKey:@"borderHeight"] floatValue])];
        self.borderView.backgroundColor = [UIColor colorWithHexString:[current valueForKey:@"borderColor"]
                                                           alpha:1.0];
        self.borderView.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
        [self addSubview:self.borderView];
        
        
        CGFloat actualHeight = [self updateHeightOfMessageView]; // this call also takes care of positioning the labels
        self.frame = CGRectMake(0.0, -actualHeight, self.frame.size.width, actualHeight);
        self.autoresizingMask = (UIViewAutoresizingFlexibleWidth);
        
        
        _gestureRec = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                action:@selector(fadeMeOut)];
        [self.gestureRec setDirection:UISwipeGestureRecognizerDirectionUp];
        [self addGestureRecognizer:self.gestureRec];
        
        _tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                          action:@selector(fadeMeOut)];
        [self addGestureRecognizer:self.tapRec];
    }
    return self;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}


- (CGFloat)updateHeightOfMessageView
{
    CGFloat currentHeight;
    CGFloat screenWidth = self.viewController.view.frame.size.width;
    
    
    self.titleLabel.frame = CGRectMake(self.textSpaceLeft,
                                       TSMessageViewPadding,
                                       screenWidth - TSMessageViewPadding - self.textSpaceLeft,
                                       0.0);
    [self.titleLabel sizeToFit];
    
    if ([self.content length])
    {
        self.contentLabel.frame = CGRectMake(self.textSpaceLeft,
                                             self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height + 5.0,
                                             screenWidth - TSMessageViewPadding - self.textSpaceLeft,
                                             0.0);
        [self.contentLabel sizeToFit];
        
        currentHeight = self.contentLabel.frame.origin.y + self.contentLabel.frame.size.height;
    }
    else
    {
        // only the title was set
        currentHeight = self.titleLabel.frame.origin.y + self.titleLabel.frame.size.height;
    }
    
    currentHeight += TSMessageViewPadding;
    
    if (self.iconImageView)
    {
        // Check if that makes the popup larger (height)
        if (self.iconImageView.frame.origin.y + self.iconImageView.frame.size.height + TSMessageViewPadding > currentHeight)
        {
            currentHeight = self.iconImageView.frame.origin.y + self.iconImageView.frame.size.height;
        }
        else
        {
            // z-align
            self.iconImageView.center = CGPointMake([self.iconImageView center].x,
                                                    round(currentHeight / 2.0));
        }
    }
        
    // Correct the border position
    CGRect borderFrame = self.borderView.frame;
    borderFrame.origin.y = currentHeight;
    self.borderView.frame = borderFrame;
    
    currentHeight += self.borderView.frame.size.height;
    
    self.frame = CGRectMake(0.0, self.frame.origin.y, self.frame.size.width, currentHeight);
    
    
    self.backgroundImageView.frame = CGRectMake(self.backgroundImageView.frame.origin.x,
                                                self.backgroundImageView.frame.origin.y,
                                                screenWidth,
                                                currentHeight);
    
    return currentHeight;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self updateHeightOfMessageView];
}

- (void)fadeMeOut
{
    dispatch_async(dispatch_get_main_queue(), ^
    {
        [[TSMessage sharedMessage] performSelector:@selector(fadeOutNotification:) withObject:self];
    });
}

@end
