//
//  NavigationController.m
//  FPPicker
//
//  Created by Liyan David Chang on 6/20/12.
//  Copyright (c) 2012 Filepicker.io. All rights reserved.
//

#import "FPSaveController.h"
#import "FPInternalHeaders.h"

@interface FPSaveController () <UINavigationControllerDelegate,
                                UIPopoverControllerDelegate,
                                FPSourcePickerDelegate>

@end

@implementation FPSaveController

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil
                           bundle:nibBundleOrNil];

    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.delegate = self;

    if (!fpAPIKEY ||
        [fpAPIKEY isEqualToString:@""] ||
        [fpAPIKEY isEqualToString:@"SET_FILEPICKER.IO_APIKEY_HERE"])
    {
        NSException* apikeyException = [NSException
                                        exceptionWithName:@"Filepicker Configuration Error"
                                                   reason:@"APIKEY not set. You can get one at https://www.filepicker.io and insert it into your project's info.plist as 'Filepicker API Key'"
                                                 userInfo:nil];
        [apikeyException raise];
    }

    if (!self.data &&
        !self.dataurl)
    {
        NSLog(@"WARNING: No data specified. Continuing but saving blank file.");
        self.data = [@"" dataUsingEncoding : NSUTF8StringEncoding];
    }

    if (!self.dataType &&
        !self.dataExtension)
    {
        NSLog(@"WARNING: No data type or data extension specified");
    }

    FPSourceListController *fpSourceListController = [FPSourceListController new];

    fpSourceListController.fpdelegate = self;
    fpSourceListController.sourceNames = self.sourceNames;
    fpSourceListController.dataTypes = @[self.dataType];

    [self pushViewController:fpSourceListController
                    animated:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];

    self.sourceNames = nil;
    self.data = nil;
    self.dataurl = nil;
    self.dataType = nil;
    self.dataExtension = nil;
    self.proposedFilename = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (void)saveFileName:(NSString *)filename
                  To:(NSString *)path
{
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view
                                              animated:YES];

    hud.mode = MBProgressHUDModeDeterminate;
    hud.labelText = @"Uploading...";

    DLog(@"Saving %@%@ to %@", filename, [self getExtensionString], path);

    filename = [filename stringByAppendingString:[self getExtensionString]];

    FPUploadAssetSuccessBlock successBlock = ^(id JSON) {
        [MBProgressHUD hideAllHUDsForView:self.view
                                 animated:YES];

        [self.fpdelegate FPSaveController:self
             didFinishSavingMediaWithInfo:nil];
    };

    FPUploadAssetFailureBlock failureBlock = ^(NSError *error,
                                               id JSON) {
        [MBProgressHUD hideAllHUDsForView:self.view
                                 animated:YES];

        if ([self.fpdelegate respondsToSelector:@selector(FPSaveController:didError:)])
        {
            [self.fpdelegate FPSaveController:self
                                     didError:error];
        }
        else
        {
            [self.fpdelegate FPSaveControllerDidCancel:self];
        }
    };

    FPUploadAssetProgressBlock progressBlock = ^(float progress) {
        hud.progress = progress;
    };

    if (self.dataurl)
    {
        [FPLibrary uploadDataURL:self.dataurl
                           named:filename
                          toPath:path
                      ofMimetype:self.dataType
                     withOptions:nil
                         success:successBlock
                         failure:failureBlock
                        progress:progressBlock];
    }
    else
    {
        [FPLibrary uploadData:self.data
                        named:filename
                       toPath:path
                   ofMimetype:self.dataType
                  withOptions:nil
                      success:successBlock
                      failure:failureBlock
                     progress:progressBlock];
    }
}

- (void)saveFileLocally
{
    [MBProgressHUD showHUDAddedTo:self.view
                         animated:YES];

    if (self.dataurl)
    {
        UIImageWriteToSavedPhotosAlbum([UIImage imageWithContentsOfFile:[self.dataurl absoluteString]], nil, nil, nil);
    }
    else
    {
        UIImageWriteToSavedPhotosAlbum([UIImage imageWithData:self.data], nil, nil, nil);
    }

    [self.fpdelegate FPSaveController:self
         didFinishSavingMediaWithInfo:nil];
}

#pragma mark FPSourcePickerDelegate Methods

- (void)FPSourceController:(FPSourceController *)sourceController
      didPickMediaWithInfo:(FPMediaInfo *)info
{
    // NO-OP
}

- (void)       FPSourceController:(FPSourceController *)sourceController
    didFinishPickingMediaWithInfo:(FPMediaInfo *)info
{
    // The user saved a file to the cloud or camera roll.

    DLog(@"Saved something to a source: %@", info);

    [self.fpdelegate FPSaveController:self
         didFinishSavingMediaWithInfo:info];

    self.fpdelegate = nil;
}

- (void)                  FPSourceController:(FPSourceController *)sourceController
    didFinishPickingMultipleMediaWithResults:(NSArray *)results
{
    // NO-OP
}

- (void)FPSourceControllerDidCancel:(FPSourceController *)sourceController
{
    //The user chose to cancel when saving to the cloud or camera roll.

    DLog(@"FP Save Canceled.");

    [self.fpdelegate FPSaveControllerDidCancel:self];

    self.fpdelegate = nil;
}

#pragma mark UIPopoverControllerDelegate Methods

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    [self.fpdelegate FPSaveControllerDidCancel:self];

    self.fpdelegate = nil;
}

#pragma mark UINavigationControllerDelegate Methods

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    return;
}

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    return;
}

- (NSString *)getExtensionString
{
    if (self.dataExtension)
    {
        return [NSString stringWithFormat:@".%@", self.dataExtension];
    }
    else if (self.dataType)
    {
        CFStringRef mimeType = (__bridge CFStringRef) self.dataType;
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, mimeType, NULL);
        CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
        CFRelease(uti);

        if (extension)
        {
            return [NSString stringWithFormat:@".%@", (__bridge_transfer NSString*) extension];
        }
        else
        {
            return @"";
        }
    }
    else
    {
        return @"";
    }
}

@end
