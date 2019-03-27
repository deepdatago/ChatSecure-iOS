//
//  OTRBuddyInfoCell.m
//  Off the Record
//
//  Created by David Chiles on 3/4/14.
//  Copyright (c) 2014 Chris Ballinger. All rights reserved.
//

#import "OTRBuddyInfoCell.h"

#import "OTRBuddy.h"
#import "OTRAccount.h"
#import "OTRXMPPBuddy.h"
@import OTRAssets;
@import PureLayout;
#import "OTRDatabaseManager.h"
#import <ChatSecureCore/ChatSecureCore-Swift.h>
@import DeepDatago;

const CGFloat OTRBuddyInfoCellHeight = 80.0;

@interface OTRBuddyInfoCell ()

@property (nonatomic, strong) UILabel *nameLabel;
@property (nonatomic, strong) UILabel *identifierLabel;
@property (nonatomic, strong) UILabel *accountLabel;

@end

@implementation OTRBuddyInfoCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.nameLabel = [[UILabel alloc] initForAutoLayout];
        self.nameLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        
        self.identifierLabel = [[UILabel alloc] initForAutoLayout];
        self.identifierLabel.textColor = [UIColor darkTextColor];
        self.identifierLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
        
        self.accountLabel = [[UILabel alloc] initForAutoLayout];
        self.accountLabel.textColor = [UIColor lightGrayColor];
        self.accountLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption2];
        
        NSArray<UILabel*> *labels = @[self.nameLabel, self.identifierLabel, self.accountLabel];
        [labels enumerateObjectsUsingBlock:^(UILabel * _Nonnull label, NSUInteger idx, BOOL * _Nonnull stop) {
            label.adjustsFontSizeToFitWidth = YES;
            [self.contentView addSubview:label];
        }];
        _infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
        [self.infoButton addTarget:self action:@selector(infoButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)setThread:(id<OTRThreadOwner>)thread {
    [self setThread:thread account:nil];
}

- (void)setThread:(id<OTRThreadOwner>)thread account:(nullable OTRAccount*)account
{
    [super setThread:thread];

    NSString * name = [thread threadName];
    self.nameLabel.text = name;

    // [CRYPTO_TALK] display user account as nick name if the friend request is not approved
    OTRBuddy *tmpBuddy = (OTRBuddy*)thread;
    NSString *tmpUserName = [tmpBuddy.username componentsSeparatedByString:@"@"][0];
    DeepDatagoManager* deepDatagoManager = [DeepDatagoManager sharedInstance];
    CryptoManager* cryptoManager = [CryptoManager sharedInstance];
    NSString *tmpAllFriendsKey = [deepDatagoManager getAllFriendsKeyWithAccount:tmpUserName];
    if (tmpAllFriendsKey == nil || tmpAllFriendsKey.length == 0) {
        self.nameLabel.text = tmpUserName;
    }
    else {
        NSString *decryptedNickName = [deepDatagoManager getDecryptedNickWithAccount:tmpUserName];
        if (decryptedNickName == nil || decryptedNickName.length == 0) {
            decryptedNickName = [cryptoManager decryptStringWithSymmetricKeyWithKey:tmpAllFriendsKey base64Input:self.nameLabel.text];
        }

        if (decryptedNickName != nil && decryptedNickName.length > 0) {
            self.nameLabel.text = decryptedNickName;
            tmpBuddy.displayName = decryptedNickName;
        }
    }
    // [CRYPTO_TALK] end

    self.accountLabel.text = account.username;
    
    NSString *identifier = nil;
    if ([thread isKindOfClass:[OTRBuddy class]]) {
        OTRBuddy *buddy = (OTRBuddy*)thread;
        identifier = buddy.username;
    } else if ([thread isGroupThread]) {
        identifier = GROUP_NAME_STRING();
    }
    self.identifierLabel.text = identifier;
    
    UIColor *textColor = [UIColor darkTextColor];
    if ([thread isArchived]) {
        textColor = [UIColor lightGrayColor];
    }
    [@[self.nameLabel, self.identifierLabel] enumerateObjectsUsingBlock:^(UILabel   * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.textColor = textColor;
    }];
}

- (void)updateConstraints
{
    if (self.addedConstraints) {
        [super updateConstraints];
        return;
    }
    NSArray<UILabel*> *textLabelsArray = @[self.nameLabel,self.identifierLabel,self.accountLabel];
    
    //same horizontal contraints for all labels
    for(UILabel *label in textLabelsArray) {
        [label autoPinEdge:ALEdgeLeading toEdge:ALEdgeTrailing ofView:self.avatarImageView withOffset:OTRBuddyImageCellPadding];
        [label autoPinEdgeToSuperviewEdge:ALEdgeTrailing withInset:OTRBuddyImageCellPadding relation:NSLayoutRelationGreaterThanOrEqual];
    }
    
    [self.nameLabel autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:OTRBuddyImageCellPadding];
    
    [self.accountLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.nameLabel withOffset:3];
    
    [self.identifierLabel autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:OTRBuddyImageCellPadding];
    [super updateConstraints];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.nameLabel.textColor = [UIColor blackColor];
    self.identifierLabel.textColor = [UIColor darkTextColor];
    self.accountLabel.textColor = [UIColor lightGrayColor];
}

- (void) infoButtonPressed:(UIButton*)sender {
    if (!self.infoAction) {
        return;
    }
    self.infoAction(self, sender);
}

@end
