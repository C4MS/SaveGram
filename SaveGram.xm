#import "SaveGram.h"

#define SGLOG(fmt, ...) NSLog((@"[SaveGram] %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

/*
 ___      _______  _______  _______  ___      _______ 
|   |    |       ||       ||   _   ||   |    |       |
|   |    |   _   ||       ||  |_|  ||   |    |    ___|
|   |    |  | |  ||       ||       ||   |    |   |___ 
|   |___ |  |_|  ||      _||       ||   |___ |    ___|
|       ||       ||     |_ |   _   ||       ||   |___ 
|_______||_______||_______||__| |__||_______||_______|
*/
static NSString *kSaveGramForeignReportKey = @"3edc99f3", *kSaveGramForeignDeleteKey = @"d5c08750", *kSaveGramForeignSaveKey = @"bb441b0b";

static NSString * savegram_reportString() {
	if ([%c(IGLocaleHelper) localeIsEnglish]) {
		return @"Report Inappropriate";
	}

	else {
		return [[NSBundle mainBundle] localizedStringForKey:kSaveGramForeignReportKey value:@"Report Inappropriate" table:@"Localizable"];
	}
}

static NSString * savegram_deleteString() {
	if ([%c(IGLocaleHelper) localeIsEnglish]) {
		return @"Delete";
	}

	else {
		return [[NSBundle mainBundle] localizedStringForKey:kSaveGramForeignDeleteKey value:@"Delete" table:@"Localizable"];
	}
}

static NSString * savegram_saveString() {
	if ([%c(IGLocaleHelper) localeIsEnglish]) {
		return @"Save";
	}

	else {
		return [[NSBundle mainBundle] localizedStringForKey:kSaveGramForeignSaveKey value:@"Save" table:@"Localizable"];
	}
}

/*
 ___      _______  _______  _______  _______  __   __ 
|   |    |       ||       ||   _   ||       ||  | |  |
|   |    |    ___||    ___||  |_|  ||       ||  |_|  |
|   |    |   |___ |   | __ |       ||       ||       |
|   |___ |    ___||   ||  ||       ||      _||_     _|
|       ||   |___ |   |_| ||   _   ||     |_   |   |  
|_______||_______||_______||__| |__||_______|  |___|                                                                                             
*/
%group FirstSupportPhase

%hook IGActionSheet

// Not sure if the IGActionSheet is used in any case besides image/video options,
// but if it was, the .topMostViewController or .delegate properties might be nice
- (void)showWithTitle:(NSString *)title {
	SGLOG(@"Detected action sheet from item, adding save option...");
	
	[self addButtonWithTitle:@"Save" style:0];
	%orig(title);
}

%end


%hook IGFeedItemActionCell

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {
		// Instead of opting for intelligent version checking when launching Instagram
		// (ala SlickGram), this segment uses try/catches to prevent crashing and only
		// notify the user when things /actually/ aren't working.
		@try{
			IGFeedItem *post = self.feedItem;
			SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL = [post imageURLForImageVersion:[%c(IGPost) fullSizeImageVersionForDevice]];
				UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

				UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
				SGLOG(@"Finished saving photo (%@) to photo library.", image);
			}

			else {
				int videoVersion;
				if ([%c(IGPost) respondsToSelector:@selector(fullSizeVideoVersionForDevice)]) {
					videoVersion = [%c(IGPost) fullSizeVideoVersionForDevice];
				}

				else {
					videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];
				}

				NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
				NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
					NSFileManager *fileManager = [NSFileManager defaultManager];
				    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
				    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
				    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

					UISaveVideoAtPathToSavedPhotosAlbum(videoSavedURL.path, self, @selector(savegram_removeVideoAtPath:didFinishSavingWithError:contextInfo:), NULL);
				}];

				[videoDownloadTask resume];
			}
		} // end @try

		@catch (NSException *e) {
			UIAlertView *errorView = [[UIAlertView alloc] initWithTitle:@"Oops!" message:[NSString stringWithFormat:@"Looks like SaveGram had trouble saving this post. Please send the following error message to @insanj: %@", e.reason] delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
			[errorView show];
			[errorView release];
		}
	}

	else {
		%orig(title);
	}
}

%new - (void)savegram_removeVideoAtPath:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	if (error) {
		SGLOG(@"Couldn't save video to photo library: %@", [error localizedDescription]);
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
	if (error) {
		SGLOG(@"Couldn't remove video from temporary location: %@", [error localizedDescription]);
		return;
	}

	SGLOG(@"Finished saving video to photo library.");
}

%end

%end // %group FirstSupportPhase

%group SecondSupportPhase

%hook IGActionSheet

+ (void)showWithDelegate:(id)arg1 {
	[self addButtonWithTitle:@"Save" style:0];
	%orig(arg1);
}

+ (void)showWithCallback:(id)arg1 {
	[self addButtonWithTitle:@"Save" style:0];
	%orig(arg1);
}

%end

%hook IGFeedItemActionCell

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:@"Save"]) {
		// Instead of opting for intelligent version checking when launching Instagram
		// (ala SlickGram), this segment uses try/catches to prevent crashing and only
		// notify the user when things /actually/ aren't working.
		@try{
			IGFeedItem *post = self.feedItem;
			SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

			if (post.mediaType == 1) {
				NSURL *imageURL = [post imageURLForFullSizeImage];
				UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:imageURL]];

				UIImageWriteToSavedPhotosAlbum(image, nil, NULL, NULL);
				SGLOG(@"Finished saving photo (%@) to photo library.", image);
			}

			else {
				NSInteger videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];

				NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
				NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
					NSFileManager *fileManager = [NSFileManager defaultManager];
				    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
				    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
				    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

					UISaveVideoAtPathToSavedPhotosAlbum(videoSavedURL.path, self, @selector(savegram_removeVideoAtPath:didFinishSavingWithError:contextInfo:), NULL);
				}];

				[videoDownloadTask resume];
			}
		} // end @try

		@catch (NSException *e) {
			UIAlertView *errorView = [[UIAlertView alloc] initWithTitle:@"Oops!" message:[NSString stringWithFormat:@"Looks like SaveGram had trouble saving this post. Please send the following error message to @insanj: %@", e.reason] delegate:nil cancelButtonTitle:@"Dimiss" otherButtonTitles:nil];
			[errorView show];
			[errorView release];
		}
	}

	else {
		%orig(title);
	}
}

%new - (void)savegram_removeVideoAtPath:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
	if (error) {
		SGLOG(@"Couldn't save video to photo library: %@", error);
		return;
	}

	[[NSFileManager defaultManager] removeItemAtPath:videoPath error:&error];
	if (error) {
		SGLOG(@"Couldn't remove video from temporary location: %@", error);
		return;
	}

	SGLOG(@"Finished saving video to photo library.");
}

%end

%end // %group SecondSupportPhase

/*                                                                                                                                                                                                                                                                    
 _______  __   __  ______    ______    _______  __    _  _______ 
|       ||  | |  ||    _ |  |    _ |  |       ||  |  | ||       |
|       ||  | |  ||   | ||  |   | ||  |    ___||   |_| ||_     _|
|       ||  |_|  ||   |_||_ |   |_||_ |   |___ |       |  |   |  
|      _||       ||    __  ||    __  ||    ___||  _    |  |   |  
|     |_ |       ||   |  | ||   |  | ||   |___ | | |   |  |   |  
|_______||_______||___|  |_||___|  |_||_______||_|  |__|  |___|  
*/
%group ThirdSupportPhase

static ALAssetsLibrary *kSaveGramAssetsLibrary = [[ALAssetsLibrary alloc] init];

%hook IGActionSheet

 - (void)show {
 	if ([[[self.buttons firstObject] currentTitle] isEqualToString:savegram_reportString()] || [[[self.buttons firstObject] currentTitle] isEqualToString:savegram_deleteString()]) {
		[self addButtonWithTitle:savegram_saveString() style:0];
	}

	%orig();
}

%end

/*
 ______   ___   ______    _______  _______  _______ 
|      | |   | |    _ |  |       ||       ||       |
|  _    ||   | |   | ||  |    ___||       ||_     _|
| | |   ||   | |   |_||_ |   |___ |       |  |   |  
| |_|   ||   | |    __  ||    ___||      _|  |   |  
|       ||   | |   |  | ||   |___ |     |_   |   |  
|______| |___| |___|  |_||_______||_______|  |___|  
*/
%hook IGDirectedPostViewController

- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:savegram_saveString()]) {
		IGPost *post = self.post;
		SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

		if (post.mediaType == 1) {
			NSURL *postImageURL;
			if ([post respondsToSelector:@selector(imageURLForFullSizeImage)]) {
				postImageURL = [post imageURLForFullSizeImage];
			}

			else {
				postImageURL = [post imageURLForSize:CGSizeMake(2048, 2048)];
			}

			UIImage *postImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:postImageURL]];

			IGAssetWriter *postImageAssetWriter = [[%c(IGAssetWriter) alloc] initWithImage:postImage metadata:nil];
			[postImageAssetWriter writeToInstagramAlbum];
		}

		else {
			NSInteger videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];

			NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
			NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
				NSFileManager *fileManager = [NSFileManager defaultManager];
			    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
			    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
			    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

			    [%c(IGAssetWriter) writeVideoToInstagramAlbum:videoSavedURL completionBlock:nil];
			}];

			[videoDownloadTask resume];
		}
	}

	else {
		%orig(title);
	}
}
%end

%hook IGFeedItemActionCell

/*- (void)onMoreButtonPressed:(id)sender {
	[self addButtonWithTitle:savegram_saveString() style:0];
	%orig(sender);
}*/

/*
 _______  _______  _______  ______  
|       ||       ||       ||      | 
|    ___||    ___||    ___||  _    |
|   |___ |   |___ |   |___ | | |   |
|    ___||    ___||    ___|| |_|   |
|   |    |   |___ |   |___ |       |
|___|    |_______||_______||______| 
*/
- (void)actionSheetDismissedWithButtonTitled:(NSString *)title {
	if ([title isEqualToString:savegram_saveString()]) {
		IGFeedItem *post = self.feedItem;
		SGLOG(@"Detected dismissal of action sheet with Save option, trying to save %@...", post);

		if (post.mediaType == 1) {
			NSURL *postImageURL;
			if ([post respondsToSelector:@selector(imageURLForFullSizeImage)]) {
				postImageURL = [post imageURLForFullSizeImage];
			}

			else {
				postImageURL = [post imageURLForSize:CGSizeMake(2048, 2048)];
			}

			UIImage *postImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:postImageURL]];

			IGAssetWriter *postImageAssetWriter = [[%c(IGAssetWriter) alloc] initWithImage:postImage metadata:nil];
			[postImageAssetWriter writeToInstagramAlbum];
		}

		else {
			NSInteger videoVersion = [%c(IGPost) videoVersionForCurrentNetworkConditions];

			NSURL *videoURL =  [post videoURLForVideoVersion:videoVersion];
			NSURLSessionTask *videoDownloadTask = [[NSURLSession sharedSession] downloadTaskWithURL:videoURL completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
				NSFileManager *fileManager = [NSFileManager defaultManager];
			    NSURL *videoDocumentsURL = [[fileManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
			    NSURL *videoSavedURL = [videoDocumentsURL URLByAppendingPathComponent:[videoURL lastPathComponent]];
			    [fileManager moveItemAtURL:location toURL:videoSavedURL error:&error];

			    [%c(IGAssetWriter) writeVideoToInstagramAlbum:videoSavedURL completionBlock:nil];
			}];

			[videoDownloadTask resume];
		}
	}

	else {
		%orig(title);
	}
}

%end

%end // %group ThirdSupportPhase

/*                                                                                                     
 _______  _______  _______  ______   
|       ||       ||       ||    _ |  
|       ||_     _||   _   ||   | ||  
|       |  |   |  |  | |  ||   |_||_ 
|      _|  |   |  |  |_|  ||    __  |
|     |_   |   |  |       ||   |  | |
|_______|  |___|  |_______||___|  |_|
*/
%ctor {
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	NSComparisonResult supportedVersionComparisonResult = [version compare:@"6.1.2" options:NSNumericSearch];

	if (supportedVersionComparisonResult == NSOrderedDescending) {
		SGLOG(@"Detected Instagram running on newest supported version %@.", version);
		%init(ThirdSupportPhase);
	}

	else if (supportedVersionComparisonResult == NSOrderedSame) {
		SGLOG(@"Detected Instagram running on supported version %@.", version);
		%init(SecondSupportPhase);
	}

	else {
		SGLOG(@"Detected Instagram running on supported old version %@.", version);
		%init(FirstSupportPhase);
	}
}
