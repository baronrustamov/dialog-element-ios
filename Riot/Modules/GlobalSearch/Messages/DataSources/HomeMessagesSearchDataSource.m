/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2018 New Vector Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MatrixKit.h"

#import "HomeMessagesSearchDataSource.h"

#import "RoomBubbleCellData.h"

#import "ThemeService.h"
#import "GeneratedInterface-Swift.h"

#import "MXKRoomBubbleTableViewCell+Riot.h"

@implementation HomeMessagesSearchDataSource

- (void)destroy
{
    [super destroy];
}

- (void)convertHomeserverResultsIntoCells:(MXSearchRoomEventResults *)roomEventResults onComplete:(dispatch_block_t)onComplete
{
    MXKRoomDataSourceManager *roomDataSourceManager = [MXKRoomDataSourceManager sharedManagerForMatrixSession:self.mxSession];

    dispatch_group_t group = dispatch_group_create();
    
    // Convert the HS results into `RoomViewController` cells
    for (MXSearchResult *result in roomEventResults.results)
    {
        // Retrieve the local room data source thanks to the room identifier
        // Note: if no local room data source exist the result is ignored.
        NSString *roomId = result.result.roomId;
        if (roomId)
        {
            dispatch_group_enter(group);

            // Check whether the user knows this room to create the room data source if it doesn't exist.
            [roomDataSourceManager roomDataSourceForRoom:roomId create:[self.mxSession roomWithRoomId:roomId] onComplete:^(MXKRoomDataSource *roomDataSource) {

                if (roomDataSource)
                {
                    // Prepare text font used to highlight the search pattern.
                    UIFont *patternFont = [roomDataSource.eventFormatter bingTextFont];

                    // Let the `RoomViewController` ecosystem do the job
                    // The search result contains only room message events, no state events.
                    // Thus, passing the current room state is not a huge problem. Only
                    // the user display name and his avatar may be wrong.
                    RoomBubbleCellData *cellData = [[RoomBubbleCellData alloc] initWithEvent:result.result andRoomState:roomDataSource.roomState andRoomDataSource:roomDataSource];
                    if (cellData)
                    {
                        // Highlight the search pattern
                        [cellData highlightPatternInTextMessage:self.searchText withForegroundColor:ThemeService.shared.theme.tintColor andFont:patternFont];

                        // Use profile information as data to display
                        MXSearchUserProfile *userProfile = result.context.profileInfo[result.result.sender];
                        cellData.senderDisplayName = userProfile.displayName;
                        cellData.senderAvatarUrl = userProfile.avatarUrl;

                        [self->cellDataArray insertObject:cellData atIndex:0];
                    }
                }

                dispatch_group_leave(group);
            }];
        }
    }

    dispatch_group_notify(group, dispatch_get_main_queue(), ^{

        // In case of successive messages from the same room,
        // we use the pagination flag to display the room name only on the first message.
        NSString *currentRoomId;
        for (RoomBubbleCellData *cellData in self->cellDataArray)
        {
            if (currentRoomId && [currentRoomId isEqualToString:cellData.roomId])
            {
                cellData.isPaginationFirstBubble = NO;
            }
            else
            {
                cellData.isPaginationFirstBubble = YES;
                currentRoomId = cellData.roomId;
            }
        }

        onComplete();
    });
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    // Finalize cell view customization here
    if ([cell isKindOfClass:MXKRoomBubbleTableViewCell.class])
    {
        MXKRoomBubbleTableViewCell *bubbleCell = (MXKRoomBubbleTableViewCell*)cell;
        
        // Display date for each message
        [bubbleCell addDateLabel];

        RoomBubbleCellData *cellData = (RoomBubbleCellData*)[self cellDataAtIndex:indexPath.row];
        MXEvent *event = cellData.events.firstObject;

        if (event)
        {
            if (cellData.hasThreadRoot)
            {
                MXThread *thread = cellData.bubbleComponents.firstObject.thread;
                ThreadSummaryView *threadSummaryView = [[ThreadSummaryView alloc] initWithThread:thread];
                [bubbleCell.tmpSubviews addObject:threadSummaryView];

                threadSummaryView.translatesAutoresizingMaskIntoConstraints = NO;
                [bubbleCell.contentView addSubview:threadSummaryView];

                CGFloat leftMargin = RoomBubbleCellLayout.reactionsViewLeftMargin;

                CGRect bubbleComponentFrame = [bubbleCell componentFrameInContentViewForIndex:0];
                CGFloat bottomPositionY = bubbleComponentFrame.origin.y + bubbleComponentFrame.size.height;

                // Set constraints for the summary view
                [NSLayoutConstraint activateConstraints: @[
                    [threadSummaryView.leadingAnchor constraintEqualToAnchor:threadSummaryView.superview.leadingAnchor
                                                        constant:leftMargin],
                    [threadSummaryView.topAnchor constraintEqualToAnchor:threadSummaryView.superview.topAnchor
                                                                    constant:bottomPositionY + RoomBubbleCellLayout.threadSummaryViewTopMargin],
                    [threadSummaryView.heightAnchor constraintEqualToConstant:[ThreadSummaryView contentViewHeightForThread:thread fitting:cellData.maxTextViewWidth]],
                    [threadSummaryView.trailingAnchor constraintLessThanOrEqualToAnchor:threadSummaryView.superview.trailingAnchor constant:-RoomBubbleCellLayout.reactionsViewRightMargin]
                ]];
            }
            else if (event.isInThread)
            {
                FromThreadView *fromThreadView = [FromThreadView instantiate];
                [bubbleCell.tmpSubviews addObject:fromThreadView];

                fromThreadView.translatesAutoresizingMaskIntoConstraints = NO;
                [bubbleCell.contentView addSubview:fromThreadView];

                CGFloat leftMargin = RoomBubbleCellLayout.reactionsViewLeftMargin;

                CGRect bubbleComponentFrame = [bubbleCell componentFrameInContentViewForIndex:0];
                CGFloat bottomPositionY = bubbleComponentFrame.origin.y + bubbleComponentFrame.size.height;

                // Set constraints for the summary view
                [NSLayoutConstraint activateConstraints: @[
                    [fromThreadView.leadingAnchor constraintEqualToAnchor:fromThreadView.superview.leadingAnchor
                                                        constant:leftMargin],
                    [fromThreadView.topAnchor constraintEqualToAnchor:fromThreadView.superview.topAnchor
                                                                    constant:bottomPositionY + RoomBubbleCellLayout.fromThreadViewTopMargin],
                    [fromThreadView.heightAnchor constraintEqualToConstant:[FromThreadView contentViewHeightForEvent:event fitting:cellData.maxTextViewWidth]],
                    [fromThreadView.trailingAnchor constraintLessThanOrEqualToAnchor:fromThreadView.superview.trailingAnchor constant:-RoomBubbleCellLayout.reactionsViewRightMargin]
                ]];
            }
        }
    }
    
    return cell;
}

@end
