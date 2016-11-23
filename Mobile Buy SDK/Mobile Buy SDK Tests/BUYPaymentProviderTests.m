//
//  BUYPaymentProviderTests.m
//  Mobile Buy SDK
//
//  Created by Shopify.
//  Copyright (c) 2015 Shopify Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

@import XCTest;

#import <Buy/Buy.h>

#import "BUYWebCheckoutPaymentProvider.h"
#import "BUYClientTestBase.h"
#import "BUYPaymentController.h"
#import "BUYFakeSafariController.h"
#import <OHHTTPStubs/OHHTTPStubs.h>

extern Class SafariViewControllerClass;

@interface BUYPaymentController (Private)
- (id <BUYPaymentProvider>)providerForType:(NSString *)type;
@end

@interface BUYPaymentProviderTests : XCTestCase <BUYPaymentProviderDelegate>

@property (nonatomic) NSMutableDictionary <NSString *, XCTestExpectation *> *expectations;
@property (nonatomic) BUYModelManager *modelManager;

@end

@implementation BUYPaymentProviderTests

- (void)setUp
{
	[super setUp];
	self.modelManager = [BUYModelManager modelManager];
	self.expectations = [@{} mutableCopy];
	
	/* ---------------------------------
	 * We need to kick off the provider
	 * class initialization before setting
	 * the fake safari controller to
	 * prevent it getting overriden.
	 */
	[BUYWebCheckoutPaymentProvider class];
	SafariViewControllerClass = [BUYFakeSafariController class];
}

- (void)tearDown
{
	[super tearDown];
	[OHHTTPStubs removeAllStubs];
}

- (BUYClient *)client
{
	return [[BUYClient alloc] initWithShopDomain:BUYShopDomain_Placeholder apiKey:BUYAPIKey_Placeholder appId:BUYAppId_Placeholder];
}

- (BUYCheckout *)checkout
{
	return [self.modelManager insertCheckoutWithJSONDictionary:nil];
}

- (void)mockRequests
{
	// This mocks a getShop, and createCheckout request
	[OHHTTPStubs stubRequestsPassingTest:^BOOL(NSURLRequest * _Nonnull request) {
		return YES;
	} withStubResponse:^OHHTTPStubsResponse * _Nonnull(NSURLRequest * _Nonnull request) {
		return [BUYPaymentProviderTests responseForRequest:request];
	}];
}

+ (OHHTTPStubsResponse *)responseForRequest:(NSURLRequest *)request
{
	NSURLComponents *components = [NSURLComponents componentsWithURL:request.URL resolvingAgainstBaseURL:NO];
	
	if ([components.path isEqualToString:@"/meta.json"]) {
		return [OHHTTPStubsResponse responseWithJSONObject:@{@"id": @"123", @"name": @"test_shop", @"country": @"US", @"currency": @"USD"} statusCode:200 headers:nil];
	}
	else if ([components.path isEqualToString:@"/api/checkouts.json"]) {
		return [OHHTTPStubsResponse responseWithJSONObject:@{@"checkout":@{@"payment_due": @(99), @"web_checkout_url": @"https://example.com"}} statusCode:200 headers:nil];
	}
	
	return nil;
}

#pragma mark - Apple Pay
#pragma mark - Web

- (void)testWebAvailability
{
	BUYWebCheckoutPaymentProvider *webProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
	XCTAssertTrue(webProvider.isAvailable);
}

- (void)testWebPresentationCallbacks
{
	[self mockRequests];
	
	BUYWebCheckoutPaymentProvider *webProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
	webProvider.delegate = self;
	
	self.expectations[@"presentController"] = [self expectationWithDescription:NSStringFromSelector(_cmd)];

	[webProvider startCheckout:self.checkout];
	
	[self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

#pragma mark - Payment Controller


- (void)testStartingPaymentWithPaymentController
{
	[self mockRequests];
	
	BUYPaymentController *controller = [[BUYPaymentController alloc] init];
	BUYWebCheckoutPaymentProvider *webProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
	webProvider.delegate = self;
	[controller addPaymentProvider:webProvider];

	self.expectations[@"presentController"] = [self expectationWithDescription:NSStringFromSelector(_cmd)];

	[controller startCheckout:self.checkout withProviderType:BUYWebPaymentProviderId];
	
	[self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
		XCTAssertNil(error);
	}];
}

#pragma mark - Payment Provider delegate

- (void)paymentProvider:(id <BUYPaymentProvider>)provider wantsControllerPresented:(UIViewController *)controller
{
	[self.expectations[@"presentController"] fulfill];
}

- (void)paymentProviderWantsControllerDismissed:(id <BUYPaymentProvider>)provider
{
	
}

- (void)paymentProviderWillStartCheckout:(id <BUYPaymentProvider>)provider
{
	
}

- (void)paymentProviderDidDismissCheckout:(id <BUYPaymentProvider>)provider
{
	
}

- (void)paymentProvider:(id <BUYPaymentProvider>)provider didFailToUpdateCheckoutWithError:(NSError *)error
{
}

- (void)paymentProvider:(id <BUYPaymentProvider>)provider didFailWithError:(NSError *)error;
{
	if (self.expectations[@"failedCheckout"]) {
		[self.expectations[@"failedCheckout"] fulfill];
		[self.expectations removeObjectForKey:@"failedCheckout"];
	}
	
	if (self.expectations[@"failedShop"]) {
		[self.expectations[@"failedShop"] fulfill];
		[self.expectations removeObjectForKey:@"failedShop"];
	}
}

- (void)paymentProvider:(id <BUYPaymentProvider>)provider didCompleteCheckout:(BUYCheckout *)checkout withStatus:(BUYStatus)status
{
	
}


@end
