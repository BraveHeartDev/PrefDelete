#import <dlfcn.h>
#import <Preferences/Preferences.h>

#define FOUND_TITLE @"Status"
#define FOUND_OK_TITLE @"Uninstall"
#define ERROR_CANCLE_TITLE @"Dismiss"

@interface PrefsListController : NSObject
-(void)reloadSpecifiers;
@end

NSString *bundleID = nil;
PSListController *controller = nil;

__attribute__((unused)) static NSMutableString *outputForShellCommand(NSString *cmd) {
	FILE *fp;
	char buf[1024];
	NSMutableString* finalRet;

	fp = popen([cmd UTF8String], "r");
	if (fp == NULL) {
		return nil;
	}

	fgets(buf, 1024, fp);
	finalRet = [NSMutableString stringWithUTF8String:buf];

	if(pclose(fp) != 0) {
		return nil;
	}

	return finalRet;
}

void searchDirectory(NSString* path, NSMutableArray** allDirectories)
{
	NSError *error = nil;
	NSArray *tempArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
	for(NSString *curItem in tempArray)
	{
		NSString *newPath = [NSString stringWithFormat:@"%@/%@", path, curItem];
		BOOL isDir = false;
		[[NSFileManager defaultManager] fileExistsAtPath:newPath isDirectory:&isDir];
		if(isDir)
			searchDirectory(newPath,allDirectories);
		else
		{
			if(![curItem hasSuffix:@".plist"])
				continue;
			
			[*allDirectories addObject:newPath];
		}
	}
}

@interface TweakClass: NSObject <UIAlertViewDelegate>
-(void)longPress:(UILongPressGestureRecognizer *)recognizer;
@end
@implementation TweakClass
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if([alertView.title isEqualToString:FOUND_TITLE])
	{
		NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
		if([buttonTitle isEqualToString:FOUND_OK_TITLE])
		{
			NSString *command = [NSString stringWithFormat:@"/usr/libexec/PrefDelete/setuid /usr/libexec/PrefDelete/uninstallPref.sh %@", bundleID];
			outputForShellCommand(command);
			[NSThread sleepForTimeInterval:1];
			[controller reloadSpecifiers];
		}
	}
}

-(void)longPress:(UILongPressGestureRecognizer *)recognizer
{
	if( recognizer.state == UIGestureRecognizerStateBegan )
	{
		bundleID = nil;

		PSTableCell *cell = (PSTableCell *)recognizer.view;
		NSString *title = cell.specifier.identifier;

		NSString *dir = @"/Library/PreferenceLoader/Preferences";
		NSMutableArray *alldirs = [[NSMutableArray alloc]init];

		searchDirectory(dir,&alldirs);

		NSString *correctDir = nil;
		for(NSString *path in alldirs)
		{
			NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:path];
			if(dict)
			{
				NSDictionary *entry = [dict valueForKey:@"entry"];
				if(entry)
				{
					NSString *label = [entry valueForKey:@"label"];
					if(label)
					{
						if([label isEqualToString:title])
						{
							correctDir = path;
							break;
						}
					}
				}
			}
		}

		if(correctDir)
		{
			NSString *packagesDir = @"/var/lib/dpkg/info";
			NSError *error = nil;
			NSArray *tempArray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:packagesDir error:&error];
			for(NSString *curPackage in tempArray)
			{
				if(![curPackage hasSuffix:@".list"])
					continue;

				NSString *newPackagePath = [NSString stringWithFormat:@"%@/%@", packagesDir, curPackage];
				NSString *content =  [NSString stringWithContentsOfFile:newPackagePath encoding:NSUTF8StringEncoding error:&error];
				if(content)
				{
					BOOL found = false;
					NSArray *newLineSeperatedContents = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
					for(NSString *line in newLineSeperatedContents)
					{
						if([line rangeOfString:correctDir].location != NSNotFound)
						{
							found = true;
							break;
						}
					}
					if(found)
					{
						bundleID = [curPackage substringToIndex:[curPackage length] - 5];
						break;
					}
				}
			}
		}

		if(bundleID)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:FOUND_TITLE message:[NSString stringWithFormat:@"%@ (%@) has been found. Do you wish to uninstall?", title, bundleID] delegate:self cancelButtonTitle:@"NO" otherButtonTitles:FOUND_OK_TITLE,nil];

			[alert show];
		}
		else
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Package not found. This cell is not a tweak cell (system cell/App cell)." delegate:nil cancelButtonTitle:ERROR_CANCLE_TITLE otherButtonTitles:nil];

			[alert show];
		}
	}
}
@end

TweakClass *tweak = nil;

%ctor
{
	dlopen("/Library/MobileSubstrate/DynamicLibraries/PreferenceOrganizer.dylib", RTLD_NOW | RTLD_GLOBAL);
	dlopen("/Library/MobileSubstrate/DynamicLibraries/PreferenceOrganizer2.dylib", RTLD_NOW | RTLD_GLOBAL);
	tweak = [[TweakClass alloc]init];
}


//Support for PreferenceOrganizer2
@interface TweakSpecifiersController : PSListController
- (NSArray *)specifiers;
@end

%hook TweakSpecifiersController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = %orig;

	//Normal, since outside section
	controller = (PSListController*)self;

	PSTableCell *tableCell = (PSTableCell*)cell;
	UILongPressGestureRecognizer *tapRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:tweak action:@selector(longPress:)];
	tapRecognizer.minimumPressDuration = 0.8; //seconds
	[tableCell addGestureRecognizer:tapRecognizer];

	return cell;
}
%end

//Support for PreferenceOrganizer7
@interface CydiaSpecifiersController : PSListController
@end
%hook CydiaSpecifiersController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = %orig;

	//Normal, since outside section
	controller = (PSListController*)self;

	PSTableCell *tableCell = (PSTableCell*)cell;
	UILongPressGestureRecognizer *tapRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:tweak action:@selector(longPress:)];
	tapRecognizer.minimumPressDuration = 0.8; //seconds
	[tableCell addGestureRecognizer:tapRecognizer];

	return cell;
}
%end

%hook PrefsListController

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = %orig;
	
	controller = (PSListController*)self;

	PSTableCell *tableCell = (PSTableCell*)cell;
	UILongPressGestureRecognizer *tapRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:tweak action:@selector(longPress:)];
	tapRecognizer.minimumPressDuration = 0.8; //seconds
	[tableCell addGestureRecognizer:tapRecognizer];

	return cell;
}
%end