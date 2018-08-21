//
//  OTRBaseLoginViewController.m
//  ChatSecure
//
//  Created by David Chiles on 5/12/15.
//  Copyright (c) 2015 Chris Ballinger. All rights reserved.
//

#import "OTRBaseLoginViewController.h"
#import "OTRColors.h"
#import "OTRCertificatePinning.h"
#import "OTRConstants.h"
#import "OTRXMPPError.h"
#import "OTRDatabaseManager.h"
#import "OTRAccount.h"
@import MBProgressHUD;
#import "OTRXLFormCreator.h"
#import <ChatSecureCore/ChatSecureCore-Swift.h>
#import "OTRXMPPServerInfo.h"
#import "OTRXMPPAccount.h"
@import OTRAssets;

#import "OTRInviteViewController.h"
#import "NSString+ChatSecure.h"
#import "XMPPServerInfoCell.h"
@import SAMKeychain;

static NSUInteger kOTRMaxLoginAttempts = 5;

@interface OTRBaseLoginViewController ()

@property (nonatomic) bool showPasswordsAsText;
@property (nonatomic) bool existingAccount;
@property (nonatomic) NSUInteger loginAttempts;

@end

@implementation OTRBaseLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [OTRUsernameCell registerCellClass:[OTRUsernameCell defaultRowDescriptorType]];
    
    self.loginAttempts = 0;
    self.tempPassword = nil;
    
    UIImage *checkImage = [UIImage imageNamed:@"ic-check" inBundle:[OTRAssets resourcesBundle] compatibleWithTraitCollection:nil];
    UIBarButtonItem *checkButton = [[UIBarButtonItem alloc] initWithImage:checkImage style:UIBarButtonItemStylePlain target:self action:@selector(loginButtonPressed:)];
    
    self.navigationItem.rightBarButtonItem = checkButton;
    
    if (self.readOnly) {
        self.title = ACCOUNT_STRING();
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (self.showsCancelButton) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelButtonPressed:)];
    }
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.tableView reloadData];
    [self.loginHandler moveAccountValues:self.account intoForm:self.form];
    
    // We need to refresh the username row with the default selected server
    [self updateUsernameRow];
}

- (void)setAccount:(OTRAccount *)account
{
    _account = account;
    [self.loginHandler moveAccountValues:self.account intoForm:self.form];
}

- (void) cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)populateAccount
{
    // [CRYPTO_TALK] just take password to create ethereum account
    NSString *password = [[self.form formRowWithTag:kOTRXLFormPasswordTextFieldTag] value];
    NSString *nickName = [[self.form formRowWithTag:kOTRXLFormNicknameTextFieldTag] value];
    DeepDatagoManager *deepDatagoManager = [[DeepDatagoManager alloc] init];
    // NSString *post = [deepDatagoManager getRegisterRequestWithPassword:(password)];
    NSString *post = [deepDatagoManager getRegisterRequestWithPassword:(password) nickName:nickName];
    if (post == nil) {
        return;
    }
    
    // NSString *post = [NSString stringWithFormat:@"Username=%@&Password=%@",@"username",@"password"];
    NSData *postData = [post dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    NSString *postLength = [NSString stringWithFormat:@"%ld",[postData length]];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setURL:[NSURL URLWithString:@"https://dev.deepdatago.com/service/accounts/register/"]];
    [request setHTTPMethod:@"POST"];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:postData];
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*) response;
    long myCode = [httpResponse statusCode];
    id responseJson = nil;
    if (myCode == 200) {
        responseJson = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSLog(@"%@",[responseJson objectForKey:@"xmppAccountPassword"]);
        
    }
    
    
    // NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    /*
     NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
     if(conn) {
     NSLog(@"Connection Successful");
     } else {
     NSLog(@"Connection could not be made");
     }
     */
    
    {
        /*
         OTRXMPPAccount *account = nil;
         if (!intoAccount) {
         BOOL useTor = [[form formRowWithTag:kOTRXLFormUseTorTag].value boolValue];
         OTRAccountType accountType = OTRAccountTypeJabber;
         if (useTor) {
         accountType = OTRAccountTypeXMPPTor;
         }
         account = [OTRAccount accountWithUsername:@"" accountType:accountType];
         if (!account) {
         return nil;
         }
         } else {
         account = [intoAccount copy];
         }
         
         NSString *nickname = [[form formRowWithTag:kOTRXLFormNicknameTextFieldTag] value];
         
         XLFormRowDescriptor *usernameRow = [form formRowWithTag:kOTRXLFormUsernameTextFieldTag];
         */
        OTRXMPPAccount *account = nil;
        OTRAccountType accountType = OTRAccountTypeJabber;
        account = [OTRAccount accountWithUsername:@"" accountType:accountType];
        
        // NSString *nickname = [[self.form formRowWithTag:kOTRXLFormNicknameTextFieldTag] value];
        NSString *encryptedNick = [deepDatagoManager getPasswordForAllFriends];
        // XLFormRowDescriptor *usernameRow = [responseJson objectForKey:@"xmppAccountNumber"] + "@dev.deepdatago.com";
        
        NSString *jidNode = [responseJson objectForKey:@"xmppAccountNumber"]; // aka 'username' from username@example.com
        NSString *jidDomain = @"dev.deepdatago.com";
        account.rememberPassword = YES;
        account.password = [responseJson objectForKey:@"xmppAccountPassword"];
        self.tempPassword = [responseJson objectForKey:@"xmppAccountPassword"];
        account.autologin = YES;
        account.domain = @"dev.deepdatago.com";
        account.port = 5222;
        account.disableAutomaticURLFetching = NO;

        int randomNumber = arc4random() % 99999;
        account.resource = [NSString stringWithFormat:@"zom%d",randomNumber];

        // account.resource = @"zom7893"; // [CRYPTO_TALK] TBD, a random number
        
        /*
         if (![usernameRow isHidden]) {
         NSArray *components = [usernameRow.value componentsSeparatedByString:@"@"];
         if (components.count == 2) {
         jidNode = [components firstObject];
         jidDomain = [components lastObject];
         } else {
         jidNode = usernameRow.value;
         }
         }
         
         if (!jidNode.length) {
         // strip whitespace and make nickname lowercase
         jidNode = [nickname stringByReplacingOccurrencesOfString:@" " withString:@""];
         jidNode = [jidNode lowercaseString];
         }
         NSNumber *rememberPassword = [[form formRowWithTag:kOTRXLFormRememberPasswordSwitchTag] value];
         if (rememberPassword) {
         account.rememberPassword = [rememberPassword boolValue];
         } else {
         account.rememberPassword = YES;
         }
         
         NSString *password = [[form formRowWithTag:kOTRXLFormPasswordTextFieldTag] value];
         
         if (password && password.length > 0) {
         account.password = password;
         } else if (account.password.length == 0) {
         // No password in field, generate strong password for user
         account.password = [OTRPasswordGenerator passwordWithLength:20];
         }
         
         NSNumber *autologin = [[form formRowWithTag:kOTRXLFormLoginAutomaticallySwitchTag] value];
         if (autologin) {
         account.autologin = [autologin boolValue];
         } else {
         account.autologin = YES;
         }
         // Don't login automatically for Tor accounts
         if (account.accountType == OTRAccountTypeXMPPTor) {
         account.autologin = NO;
         }
         
         NSString *hostname = [[form formRowWithTag:kOTRXLFormHostnameTextFieldTag] value];
         NSNumber *port = [[form formRowWithTag:kOTRXLFormPortTextFieldTag] value];
         NSString *resource = [[form formRowWithTag:kOTRXLFormResourceTextFieldTag] value];
         
         if (![hostname length]) {
         XLFormRowDescriptor *serverRow = [form formRowWithTag:kOTRXLFormXMPPServerTag];
         if (serverRow) {
         OTRXMPPServerInfo *serverInfo = serverRow.value;
         hostname = serverInfo.domain;
         }
         }
         account.domain = hostname;
         
         
         if (port) {
         account.port = [port intValue];
         }
         
         if ([resource length]) {
         account.resource = resource;
         }
         NSNumber *autofetch = [form formRowWithTag:kOTRXLFormAutomaticURLFetchTag].value;
         if (autofetch) {
         account.disableAutomaticURLFetching = !autofetch.boolValue;
         }
         
         // Post-process values via XMPPJID for stringprep
         
         if (!jidDomain.length) {
         jidDomain = account.domain;
         }
         */
        XMPPJID *jid = [XMPPJID jidWithUser:jidNode domain:jidDomain resource:account.resource];
        if (!jid) {
            NSParameterAssert(jid != nil);
            // DDLogError(@"Error creating JID from account values!");
        }
        account.username = jid.bare;
        account.resource = jid.resource;
        account.displayName = encryptedNick;
        
        // Use server's .onion if possible, else use FQDN
        if (account.accountType == OTRAccountTypeXMPPTor) {
            /*
             OTRXMPPServerInfo *serverInfo = [[form formRowWithTag:kOTRXLFormXMPPServerTag] value];
             OTRXMPPTorAccount *torAccount = (OTRXMPPTorAccount*)self.account;
             torAccount.onion = serverInfo.onion;
             if (torAccount.onion.length) {
             torAccount.domain = torAccount.onion;
             } else if (serverInfo.server.length) {
             torAccount.domain = serverInfo.server;
             }
             */
        }
        
        // Start generating our OTR key here so it's ready when we need it
        
        [OTRProtocolManager.encryptionManager.otrKit generatePrivateKeyForAccountName:account.username protocol:kOTRProtocolTypeXMPP completion:^(OTRFingerprint *fingerprint, NSError *error) {
            NSParameterAssert(fingerprint.fingerprint.length > 0);
            if (fingerprint.fingerprint.length > 0) {
                NSLog(@"Fingerprint generated for %@: %@",jid.bare, fingerprint);
                
                // DDLogVerbose(@"Fingerprint generated for %@: %@", jid.bare, fingerprint);
            } else {
                // DDLogError(@"Error generating fingerprint for %@: %@", jid.bare, error);
                NSLog(@"Error generating fingerprint for %@: %@", jid.bare, error);
            }
        }];
        self.account =  account;
        
        
        // return account;
    }
}

- (void)loginButtonPressed:(id)sender
{
    if (self.readOnly) {
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    self.existingAccount = (self.account != nil);
    // [CRYPTO_TALK] populate account
    if (self.account == nil) {
        [self populateAccount];
    }
    else {
        OTRXMPPAccount *account = self.account;
        account.password = self.tempPassword;
    }

    // if ([self validForm])
    if (self.tempPassword != nil)
    {
        self.form.disabled = YES;
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.navigationItem.rightBarButtonItem.enabled = NO;
        self.navigationItem.leftBarButtonItem.enabled = NO;
        self.navigationItem.backBarButtonItem.enabled = NO;

		__weak __typeof__(self) weakSelf = self;
        self.loginAttempts += 1;
        [self.loginHandler performActionWithValidForm:nil account:self.account progress:^(NSInteger progress, NSString *summaryString) {
            NSLog(@"Tor Progress %d: %@", (int)progress, summaryString);
            hud.progress = progress/100.0f;
            hud.label.text = summaryString;
            
            } completion:^(OTRAccount *account, NSError *error) {
                __typeof__(self) strongSelf = weakSelf;
                strongSelf.form.disabled = NO;
                strongSelf.navigationItem.rightBarButtonItem.enabled = YES;
                strongSelf.navigationItem.backBarButtonItem.enabled = YES;
                strongSelf.navigationItem.leftBarButtonItem.enabled = YES;
                [hud hideAnimated:YES];
                if (error) {
                    // Unset/remove password from keychain if account
                    // is unsaved / doesn't already exist. This prevents the case
                    // where there is a login attempt, but it fails and
                    // the account is never saved. If the account is never
                    // saved, it's impossible to delete the orphaned password
                    __block BOOL accountExists = NO;
                    [[OTRDatabaseManager sharedInstance].uiConnection readWithBlock:^(YapDatabaseReadTransaction *transaction) {
                        accountExists = [transaction objectForKey:account.uniqueId inCollection:[[OTRAccount class] collection]] != nil;
                    }];
                    if (!accountExists) {
                        [account removeKeychainPassword:nil];
                    }
                    [strongSelf handleError:error];
                } else if (account) {
                    self.account = account;
                    [self handleSuccessWithNewAccount:account sender:sender];
                }
        }];
    }
}

- (void) handleSuccessWithNewAccount:(OTRAccount*)account sender:(id)sender {
    NSParameterAssert(account != nil);
    if (!account) { return; }
    [[OTRDatabaseManager sharedInstance].writeConnection readWriteWithBlock:^(YapDatabaseReadWriteTransaction *transaction) {
        [account saveWithTransaction:transaction];
    }];
    
    if (self.existingAccount) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    
    // If push isn't enabled, prompt to enable it
    if ([PushController getPushPreference] == PushPreferenceEnabled) {
        [self pushInviteViewController:sender];
    } else {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Onboarding" bundle:[OTRAssets resourcesBundle]];
        EnablePushViewController *pushVC = [storyboard instantiateViewControllerWithIdentifier:@"enablePush"];
        if (pushVC) {
            pushVC.account = account;
            [self.navigationController pushViewController:pushVC animated:YES];
        } else {
            [self pushInviteViewController:sender];
        }
    }
}

- (void) pushInviteViewController:(id)sender {
    if (self.existingAccount) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        UIViewController *inviteVC = [GlobalTheme.shared inviteViewControllerForAccount:self.account];
        [self.navigationController pushViewController:inviteVC animated:YES];
    }
}

- (BOOL)validForm
{
    BOOL validForm = YES;
    NSArray *formValidationErrors = [self formValidationErrors];
    if ([formValidationErrors count]) {
        validForm = NO;
    }
    
    [formValidationErrors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        XLFormValidationStatus * validationStatus = [[obj userInfo] objectForKey:XLValidationStatusErrorKey];
        UITableViewCell * cell = [self.tableView cellForRowAtIndexPath:[self.form indexPathOfFormRow:validationStatus.rowDescriptor]];
        cell.backgroundColor = [UIColor orangeColor];
        [UIView animateWithDuration:0.3 animations:^{
            cell.backgroundColor = [UIColor whiteColor];
        }];
        
    }];
    return validForm;
}

- (void) updateUsernameRow {
    XLFormRowDescriptor *usernameRow = [self.form formRowWithTag:kOTRXLFormUsernameTextFieldTag];
    if (!usernameRow) {
        return;
    }
    XLFormRowDescriptor *serverRow = [self.form formRowWithTag:kOTRXLFormXMPPServerTag];
    NSString *domain = nil;
    if (serverRow) {
        OTRXMPPServerInfo *serverInfo = serverRow.value;
        domain = serverInfo.domain;
        usernameRow.value = domain;
    } else {
        usernameRow.value = self.account.username;
    }
    [self updateFormRow:usernameRow];
}

#pragma mark UITableView methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    // This is required for the XMPPServerInfoCell buttons to work
    if ([cell isKindOfClass:[XMPPServerInfoCell class]]) {
        XMPPServerInfoCell *infoCell = (XMPPServerInfoCell*)cell;
        [infoCell setupWithParentViewController:self];
    }
    if (self.readOnly) {
        cell.userInteractionEnabled = NO;
    } else {
        XLFormRowDescriptor *desc = [self.form formRowAtIndex:indexPath];
        if (desc != nil && desc.tag == kOTRXLFormPasswordTextFieldTag) {
            cell.accessoryType = UITableViewCellAccessoryDetailButton;
            if ([cell isKindOfClass:XLFormTextFieldCell.class]) {
                [[(XLFormTextFieldCell*)cell textField] setSecureTextEntry:!self.showPasswordsAsText];
            }

        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    XLFormRowDescriptor *desc = [self.form formRowAtIndex:indexPath];
    if (desc != nil && desc.tag == kOTRXLFormPasswordTextFieldTag) {
        self.showPasswordsAsText = !self.showPasswordsAsText;
        [self.tableView reloadData];
    }
}

#pragma mark XLFormDescriptorDelegate

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)formRow oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:formRow oldValue:oldValue newValue:newValue];
    if (formRow.tag == kOTRXLFormXMPPServerTag) {
        [self updateUsernameRow];
    }
}

 #pragma - mark Errors and Alert Views

- (void)handleError:(NSError *)error
{
    NSParameterAssert(error);
    if (!error) {
        return;
    }
    UIAlertController *certAlert = [UIAlertController certificateWarningAlertWithError:error saveHandler:^(UIAlertAction * _Nonnull action) {
        [self loginButtonPressed:self.view];
    }];
    if (certAlert) {
        [self presentViewController:certAlert animated:YES completion:nil];
    } else {
        [self handleXMPPError:error];
    }
}

- (void)handleXMPPError:(NSError *)error
{
    if (error.code == OTRXMPPXMLErrorConflict && self.loginAttempts < kOTRMaxLoginAttempts) {
        //Caught the conflict error before there's any alert displayed on the screen
        //Create a new nickname with a random hex value at the end
        NSString *uniqueString = [[OTRPasswordGenerator randomDataWithLength:2] hexString];
        XLFormRowDescriptor* nicknameRow = [self.form formRowWithTag:kOTRXLFormNicknameTextFieldTag];
        NSString *value = [nicknameRow value];
        NSString *newValue = [NSString stringWithFormat:@"%@.%@",value,uniqueString];
        nicknameRow.value = newValue;
        [self loginButtonPressed:self.view];
        return;
    } else if (error.code == OTRXMPPXMLErrorPolicyViolation && self.loginAttempts < kOTRMaxLoginAttempts){
        // We've hit a policy violation. This occurs on duckgo because of special characters like russian alphabet.
        // We should give it another shot stripping out offending characters and retrying.
        XLFormRowDescriptor* nicknameRow = [self.form formRowWithTag:kOTRXLFormNicknameTextFieldTag];
        NSMutableString *value = [[nicknameRow value] mutableCopy];
        NSString *newValue = [value otr_stringByRemovingNonEnglishCharacters];
        if ([newValue length] == 0) {
            newValue = [OTRBranding xmppResource];
        }
        
        if (![newValue isEqualToString:value]) {
            nicknameRow.value = newValue;
            [self loginButtonPressed:self.view];
            return;
        }
    }
    
    [self showAlertViewWithTitle:ERROR_STRING() message:XMPP_FAIL_STRING() error:error];
}

- (void)showAlertViewWithTitle:(NSString *)title message:(NSString *)message error:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertAction * okButtonItem = [UIAlertAction actionWithTitle:OK_STRING() style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            
        }];
        UIAlertController * alertController = nil;
        if (error) {
            UIAlertAction * infoButton = [UIAlertAction actionWithTitle:INFO_STRING() style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                NSString * errorDescriptionString = [NSString stringWithFormat:@"%@ : %@",[error domain],[error localizedDescription]];
                NSString *xmlErrorString = error.userInfo[OTRXMPPXMLErrorKey];
                if (xmlErrorString) {
                    errorDescriptionString = [errorDescriptionString stringByAppendingFormat:@"\n\n%@", xmlErrorString];
                }
                
                if ([[error domain] isEqualToString:@"kCFStreamErrorDomainSSL"]) {
                    NSString * sslString = [OTRXMPPError errorStringWithSSLStatus:(OSStatus)error.code];
                    if ([sslString length]) {
                        errorDescriptionString = [errorDescriptionString stringByAppendingFormat:@"\n%@",sslString];
                    }
                }
                
                
                UIAlertAction * copyButtonItem = [UIAlertAction actionWithTitle:COPY_STRING() style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    NSString * copyString = [NSString stringWithFormat:@"Domain: %@\nCode: %ld\nUserInfo: %@",[error domain],(long)[error code],[error userInfo]];
                    
                    UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
                    [pasteBoard setString:copyString];
                }];
                
                UIAlertController *alert = [UIAlertController alertControllerWithTitle:INFO_STRING() message:errorDescriptionString preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:okButtonItem];
                [alert addAction:copyButtonItem];
                [self presentViewController:alert animated:YES completion:nil];
            }];
            
            alertController = [UIAlertController alertControllerWithTitle:title
                                                                  message:message
                                                           preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:okButtonItem];
            [alertController addAction:infoButton];
        }
        else {
            alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:okButtonItem];
        }
        
        if (alertController) {
            [self presentViewController:alertController animated:YES completion:nil];
        }
    });
}

#pragma - mark Class Methods

- (instancetype) initWithAccount:(OTRAccount*)account
{
    NSParameterAssert(account != nil);
    XLFormDescriptor *form = [XLFormDescriptor existingAccountFormWithAccount:account];
    if (self = [super initWithForm:form style:UITableViewStyleGrouped]) {
        self.account = account;
        self.loginHandler = [OTRLoginHandler loginHandlerForAccount:account];
    }
    return self;
}

- (instancetype) initWithExistingAccountType:(OTRAccountType)accountType {
    XLFormDescriptor *form = [XLFormDescriptor existingAccountFormWithAccountType:accountType];
    if (self = [super initWithForm:form style:UITableViewStyleGrouped]) {
        self.loginHandler = [[OTRXMPPLoginHandler alloc] init];
    }
    return self;
}

/** This is for registering new accounts on a server */
- (instancetype) initWithNewAccountType:(OTRAccountType)accountType {
    XLFormDescriptor *form = [XLFormDescriptor registerNewAccountFormWithAccountType:accountType];
    if (self = [super initWithForm:form style:UITableViewStyleGrouped]) {
        self.loginHandler = [[OTRXMPPCreateAccountHandler alloc] init];
    }
    return self;
}

@end
