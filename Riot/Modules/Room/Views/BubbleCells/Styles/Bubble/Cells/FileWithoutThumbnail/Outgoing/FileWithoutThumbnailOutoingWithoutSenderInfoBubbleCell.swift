// 
// Copyright 2021 New Vector Ltd
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import UIKit

class FileWithoutThumbnailOutoingWithoutSenderInfoBubbleCell: FileWithoutThumbnailBaseBubbleCell {
    
    override func setupViews() {
        super.setupViews()
        
        bubbleCellContentView?.showSenderInfo = false
        
        // TODO: Use constants
        // Same as outgoing message
        let rightMargin: CGFloat = 34.0
        let leftMargin: CGFloat = 80.0
        
        bubbleCellContentView?.innerContentViewTrailingConstraint.constant = rightMargin
        bubbleCellContentView?.innerContentViewLeadingConstraint.constant = leftMargin
    }
    
    override func update(theme: Theme) {
        super.update(theme: theme)
        
        self.fileAttachementView?.backgroundColor = theme.roomCellOutgoingBubbleBackgroundColor
    }
}
