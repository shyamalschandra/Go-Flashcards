//
//  CardCell.swift
//  FlashCards
//
//  Created by Roy McKenzie on 12/28/16.
//  Copyright © 2016 Roy McKenzie. All rights reserved.
//

import UIKit

class CardCell: UICollectionViewCell {

    @IBOutlet private weak var frontTextLabel: UILabel!
    @IBOutlet private weak var frontImageView: UIImageView!
    @IBOutlet private weak var visualEffectView: UIVisualEffectView!
    
    var frontText: String? {
        didSet {
            frontTextLabel.text = frontText
            layoutViews()
        }
    }
    
    var frontImage: UIImage? {
        didSet {
            frontImageView.image = frontImage
            layoutViews()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()

        visualEffectView.isHidden = true
        layer.cornerRadius = 8
    }
    
    private func layoutViews() {
        
        visualEffectView.isHidden = true
        
        if let _ = frontImage, let frontText = frontText, frontText.characters.count > 0 {
            visualEffectView.isHidden = false
        }
    }
}
