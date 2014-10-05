//
//  SDCAlertController.m
//  SDCAlertView
//
//  Created by Scott Berrevoets on 9/14/14.
//  Copyright (c) 2014 Scotty Doesn't Code. All rights reserved.
//

#import "SDCAlertController.h"

#import "SDCAlertTextFieldViewController.h"
#import "SDCAlertTransition.h"
#import "SDCAlertControllerView.h"
#import "SDCAlertControllerDefaultVisualStyle.h"
#import "SDCIntrinsicallySizedView.h"

#import "UIView+SDCAutoLayout.h"
#import "UIViewController+Current.h"

@interface SDCAlertAction (Private)
@property (nonatomic, copy) void (^handler)(SDCAlertAction *);
@end

@interface SDCAlertController () <SDCAlertControllerViewDelegate>
@property (nonatomic, strong) NSMutableArray *mutableActions;
@property (nonatomic, strong) NSMutableArray *mutableTextFields;
@property (nonatomic, strong) id<UIViewControllerTransitioningDelegate> transitioningDelegate;
@property (nonatomic, strong) id<SDCAlertControllerVisualStyle> visualStyle;
@property (nonatomic, strong) SDCAlertControllerView *alert;
@end

@implementation SDCAlertController

#pragma mark - Initialization

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(SDCAlertControllerStyle)preferredStyle {
	return [[self alloc] initWithTitle:title message:message style:preferredStyle];
}

+ (instancetype)alertControllerWithAttributedTitle:(NSAttributedString *)attributedTitle
								 attributedMessage:(NSAttributedString *)attributedMessage
									preferredStyle:(SDCAlertControllerStyle)preferredStyle {
	return [[self alloc] initWithAttributedTitle:attributedTitle attributedMessage:attributedMessage style:preferredStyle];
}

- (instancetype)initWithStyle:(SDCAlertControllerStyle)style {
	self = [super init];
	
	if (self) {
		NSAssert(style == SDCAlertControllerStyleAlert, @"Only SDCAlertControllerStyleAlert is supported by %@", NSStringFromClass([self class]));
		
		_mutableActions = [NSMutableArray array];
		_mutableTextFields = [NSMutableArray array];
		
		_visualStyle = [[SDCAlertControllerDefaultVisualStyle alloc] init];
		_buttonLayout = SDCAlertControllerButtonLayoutAutomatic;
		
		self.modalPresentationStyle = UIModalPresentationCustom;
		self.transitioningDelegate = [[SDCAlertTransitioningDelegate alloc] init];
	}
	
	return self;
}

- (instancetype)initWithTitle:(NSString *)title message:(NSString *)message style:(SDCAlertControllerStyle)style {
	self = [self initWithStyle:style];
	
	if (self) {
		self.title = title;
		_message = message;
		
		[self createAlert];
	}
	
	return self;
}

- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle
					  attributedMessage:(NSAttributedString *)attributedMessage
						 style:(SDCAlertControllerStyle)style {
	self = [self initWithStyle:style];
	
	if (self) {
		_attributedTitle = attributedTitle;
		_attributedMessage = attributedMessage;
		
		[self createAlert];
	}
	
	return self;
}

- (void)setTitle:(NSString *)title {
	[super setTitle:title];
	self.alert.title = [[NSAttributedString alloc] initWithString:title];
}

- (void)setMessage:(NSString *)message {
	_message = message;
	self.alert.message = [[NSAttributedString alloc] initWithString:message];
}

#pragma mark - Alert View

- (void)createAlert {
	NSAttributedString *title = self.attributedTitle ? : [[NSAttributedString alloc] initWithString:self.title];
	NSAttributedString *message = self.attributedMessage ? : [[NSAttributedString alloc] initWithString:self.message];
	self.alert = [[SDCAlertControllerView alloc] initWithTitle:title message:message];
	
	self.alert.delegate = self;
	self.alert.contentView = [[SDCIntrinsicallySizedView alloc] init];
	[self.alert.contentView setTranslatesAutoresizingMaskIntoConstraints:NO];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
	self.alert.visualStyle = self.visualStyle;
	self.alert.actions = self.actions;
	self.alert.buttonLayout = self.buttonLayout;
	
	[self showTextFieldsInAlertView:self.alert];
	
	[self.view addSubview:self.alert];
	[self.alert sdc_centerInSuperview];
}

- (void)showTextFieldsInAlertView:(SDCAlertControllerView *)alertView {
	if (self.textFields.count > 0) {
		SDCAlertTextFieldViewController *textFieldViewController = [[SDCAlertTextFieldViewController alloc] init];
		textFieldViewController.textFields = self.textFields;
		
		[self addChildViewController:textFieldViewController];
		[alertView showTextFieldViewController:textFieldViewController];
		[textFieldViewController didMoveToParentViewController:self];
	}
}

- (UIView *)contentView {
	return self.alert.contentView;
}

#pragma mark - Style

- (SDCAlertControllerStyle)preferredStyle {
	return SDCAlertControllerStyleAlert;
}

- (void)applyVisualStyle:(id<SDCAlertControllerVisualStyle>)visualStyle {
	_visualStyle = visualStyle;
}

#pragma mark - Alert Actions

- (void)addAction:(SDCAlertAction *)action {
	[self.mutableActions addObject:action];
}

- (NSArray *)actions {
	return [self.mutableActions copy];
}

- (void)alertControllerView:(SDCAlertControllerView *)sender didPerformAction:(SDCAlertAction *)action {
	if (!action.isEnabled || (self.shouldDismissBlock && !self.shouldDismissBlock(action))) {
		return;
	}
	
	[self dismissWithCompletion:^{
		if (action.handler) {
			action.handler(action);
		}
	}];
}

#pragma mark - Alert Text Fields

- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *))configurationHandler {
	UITextField *textField = [[UITextField alloc] init];
	textField.font = self.visualStyle.textFieldFont;
	[self.mutableTextFields addObject:textField];
	
	if (configurationHandler) {
		configurationHandler(textField);
	}
}

- (NSArray *)textFields {
	return [self.mutableTextFields copy];
}

@end

@implementation SDCAlertController (Presentation)

- (void)present {
	[self presentWithCompletion:nil];
}

- (void)presentWithCompletion:(void(^)(void))completion {
	UIViewController *currentViewController = [UIViewController currentViewController];
	[self presentFromViewController:currentViewController completionHandler:completion];
}

- (void)presentFromViewController:(UIViewController *)viewController completionHandler:(void (^)(void))completionHandler {
	[viewController presentViewController:self animated:YES completion:completionHandler];
}

- (void)dismiss {
	[self dismissWithCompletion:nil];
}

- (void)dismissWithCompletion:(void (^)(void))completion {
	[self.presentingViewController dismissViewControllerAnimated:YES completion:completion];
}

@end

@implementation SDCAlertController (Convenience)

+ (instancetype)showAlertControllerWithTitle:(NSString *)title message:(NSString *)message {
	return [self showAlertControllerWithTitle:title message:message actionTitle:nil];
}

+ (instancetype)showAlertControllerWithTitle:(NSString *)title message:(NSString *)message actionTitle:(NSString *)actionTitle {
	return [self showAlertControllerWithTitle:title message:message actionTitle:actionTitle subview:nil];
}

+ (instancetype)showAlertControllerWithTitle:(NSString *)title message:(NSString *)message actionTitle:(NSString *)actionTitle subview:(UIView *)subview {
	SDCAlertController *controller = [SDCAlertController alertControllerWithTitle:title message:message preferredStyle:SDCAlertControllerStyleAlert];
	[controller addAction:[SDCAlertAction actionWithTitle:actionTitle style:SDCAlertActionStyleCancel handler:nil]];
	
	if (subview) {
		[controller.contentView addSubview:subview];
	}
	
	[controller present];
	return controller;
}

@end