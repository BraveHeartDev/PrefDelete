#import <dlfcn.h>
#import <Preferences/Preferences.h>

#define NSLocalizedStringP(key, comment) [[NSBundle bundleWithPath:@"/Library/Application Support/PrefDelete"] localizedStringForKey:(key) value:@"" table:nil]

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
@property (nonatomic) BOOL needsRespring;

-(void)longPress:(UILongPressGestureRecognizer *)recognizer;
@end
@implementation TweakClass
@synthesize needsRespring;
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	NSString *buttonTitle = [alertView buttonTitleAtIndex:buttonIndex];
	if([alertView.title isEqualToString:NSLocalizedStringP(@"FOUND_TITLE",nil)])
	{
		if([buttonTitle isEqualToString:NSLocalizedStringP(@"FOUND_OK_TITLE",nil)])
		{
			NSString *command = [NSString stringWithFormat:@"/usr/libexec/PrefDelete/setuid /usr/libexec/PrefDelete/uninstallPref.sh %@", bundleID];
			outputForShellCommand(command);
			[NSThread sleepForTimeInterval:1];
			[controller reloadSpecifiers];

			if(needsRespring)
			{
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringP(@"RESPRING_TITLE",nil) message:NSLocalizedStringP(@"RESPRING_MESSAGE",nil) delegate:self cancelButtonTitle:NSLocalizedStringP(@"RESPRING_BUTTON",nil) otherButtonTitles:nil];
				[alert show];
			}
		}
	}
	else if([alertView.title isEqualToString:NSLocalizedStringP(@"RESPRING_TITLE",nil)])
	{
		system("killall backboardd");
	}
}

-(void)longPress:(UILongPressGestureRecognizer *)recognizer
{
	if( recognizer.state == UIGestureRecognizerStateBegan )
	{
		bundleID = nil;
		needsRespring = false;

		PSTableCell *cell = (PSTableCell *)recognizer.view;
		NSString *title = [cell.specifier propertyForKey:@"label"];//cell.specifier.identifier;

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
			NSString *dependanciesFile = [NSString stringWithContentsOfFile:@"/var/lib/dpkg/status" encoding:NSUTF8StringEncoding error:nil];
			NSArray *dependanciesArray = [dependanciesFile componentsSeparatedByString:@"Package: "];
			for(NSString *tweakData in dependanciesArray)
			{
				NSArray *dataArray = [tweakData componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
				if([dataArray[0] rangeOfString:bundleID].location != NSNotFound)
				{
					for(NSString *line in dataArray)
					{
						if([line rangeOfString:@"Depends:"].location != NSNotFound || [line rangeOfString:@"Pre-Depends:"].location != NSNotFound)
						{
							if([line rangeOfString:@"mobilesubstrate"].location != NSNotFound)
								needsRespring = true;
						}
					}
					break;
				}
			}

			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringP(@"FOUND_TITLE",nil) message:[NSString stringWithFormat:NSLocalizedStringP(@"FOUND_MESSAGE",nil), title, bundleID] delegate:self cancelButtonTitle:NSLocalizedStringP(@"NO",nil) otherButtonTitles:NSLocalizedStringP(@"FOUND_OK_TITLE",nil),nil];

			[alert show];
		}
		else
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedStringP(@"ERROR_TITLE",nil) message:NSLocalizedStringP(@"NOT_FOUND_MESSAGE",nil) delegate:nil cancelButtonTitle:NSLocalizedStringP(@"ERROR_CANCEL_TITLE",nil) otherButtonTitles:nil];

			[alert show];
		}
	}
}
@end

TweakClass *tweak = nil;

%ctor
{
	tweak = [[TweakClass alloc]init];
}

//Support for PreferenceTag
%hook TagFolder
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