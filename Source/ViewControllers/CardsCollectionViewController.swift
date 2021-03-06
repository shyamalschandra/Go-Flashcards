//
//  CardsCollectionViewController.swift
//  FlashCards
//
//  Created by Roy McKenzie on 1/24/17.
//  Copyright © 2017 Roy McKenzie. All rights reserved.
//

import UIKit
import RealmSwift

private let AddNewCard = NSLocalizedString("Add\nnew\ncard", comment: "Add a new card by tapping here")
private let DragMasteredCardsHere = NSLocalizedString("Drag\nmastered\ncards\nhere", comment: "Drag a mastered card here")
private let Mastered = NSLocalizedString("Mastered", comment: "Mastered header")

final class CardsCollectionViewController: NSObject, RealmNotifiable {
    
    weak var collectionView: UICollectionView?
    let stack: Stack
    
    var realmNotificationToken: NotificationToken?
    
    var longPressGesture: UILongPressGestureRecognizer!
    
    var dataSource: [Results<Card>] {
        get {
            return [stack.unmasteredCards, stack.masteredCards]
        }
    }
    
    var didSelectItem: ((Card?, IndexPath) -> ())?
    
    init(collectionView: UICollectionView, stack: Stack) {
        self.collectionView = collectionView
        self.stack = stack
        super.init()
        
        collectionView.registerNib(CardCell.self)
        collectionView.registerNib(BlankCardCell.self)
        collectionView.registerSupplementaryViewNib(forKind: UICollectionElementKindSectionHeader,
                                                    viewClass: CardHeaderCollectionReusableView.self)
        collectionView.delegate = self
        collectionView.dataSource = self
        
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongGesture))
        longPressGesture.minimumPressDuration = 0.3
        collectionView.addGestureRecognizer(longPressGesture)
        
        startRealmNotification { [weak self] (_, _) in
            guard let _self = self else { return }
            if _self.stack.isInvalidated || _self.stack.cards.isInvalidated {
                collectionView.delegate = nil
                collectionView.dataSource = nil
            }
        }
    }
    
    @objc func handleLongGesture(gesture: UILongPressGestureRecognizer) {
        
        switch(gesture.state) {
        case .began:
            guard let selectedIndexPath = collectionView?.indexPathForItem(at: gesture.location(in: self.collectionView)) else {
                break
            }
            collectionView?.beginInteractiveMovementForItem(at: selectedIndexPath)
        case .changed:
            collectionView?.updateInteractiveMovementTargetPosition(gesture.location(in: gesture.view!))
        case .ended:
            collectionView?.endInteractiveMovement()
        default:
            collectionView?.cancelInteractiveMovement()
        }
    }
    
    deinit {
        stopRealmNotification()
    }
}

private let CardSpacing: CGFloat = 15
extension CardsCollectionViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch (indexPath.section, indexPath.item) {
        case (1, 0) where dataSource[indexPath.section].isEmpty:
            return false
        default:
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let rowCount: CGFloat
        
        // width, height
        switch (collectionView.traitCollection.horizontalSizeClass, collectionView.traitCollection.verticalSizeClass) {
        case (.regular, .regular):
            rowCount = 5
        case (.compact, .regular):
            rowCount = 3
        case (.compact, .compact):
            rowCount = 5
        default:
            rowCount = 1
        }
        
        let totalVerticalSpacing = ((rowCount-1)*CardSpacing) + (CardSpacing*2)
        let verticalSpacingAffordance = totalVerticalSpacing / rowCount
        let width = (collectionView.frame.size.width / rowCount) - verticalSpacingAffordance
        let height = width * 1.333
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return CardSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return CardSpacing
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        switch section {
        case 0:
            return UIEdgeInsets(top: CardSpacing, left: CardSpacing, bottom: CardSpacing, right: CardSpacing)
        default:
            return UIEdgeInsets(top: 0, left: CardSpacing, bottom: CardSpacing, right: CardSpacing)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        setCellContentsFor(indexPath: indexPath, cell: cell)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let card = cardFor(indexPath)
        didSelectItem?(card, indexPath)
    }
    
    func setCellContentsFor(indexPath: IndexPath, cell: UICollectionViewCell) {
        switch (indexPath.section, indexPath.row) {
        case (0, 0),
             (1, 0) where dataSource[indexPath.section].isEmpty:
            let cell = cell as? BlankCardCell
            cell?.textLabel.text = cardTextFor(indexPath)
        default:
            let cell = cell as? CardCell
            cell?.frontImage = cardImageFor(indexPath)
            cell?.frontText = cardTextFor(indexPath)
            cell?.alpha = indexPath.section == 1 ? 0.7 : 1
        }
    }
    
    func cardFor(_ indexPath: IndexPath) -> Card? {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return nil
        case (0, let item) where item > 0:
            return dataSource[indexPath.section][item-1]
        default:
            return dataSource[indexPath.section][indexPath.item]
        }
    }
    
    func cardTextFor(_ indexPath: IndexPath) -> String? {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return AddNewCard
        case (1, 0) where dataSource[indexPath.section].isEmpty:
            return DragMasteredCardsHere
        case (0, let item) where item > 0:
            return dataSource[indexPath.section][indexPath.item-1].frontText
        default:
            return dataSource[indexPath.section][indexPath.item].frontText
        }
    }
    
    func cardImageFor(_ indexPath: IndexPath) -> UIImage? {
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            return nil
        case (1, 0) where dataSource[indexPath.section].isEmpty:
            return nil
        case (0, let item) where item > 0:
            return dataSource[indexPath.section][indexPath.item-1].frontImage
        default:
            return dataSource[indexPath.section][indexPath.item].frontImage
        }
    }
}

extension CardsCollectionViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        if dataSource[0].isEmpty && dataSource[1].isEmpty {
            return 1
        }
        return dataSource.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch section {
        case 0:
            return dataSource[section].count + 1
        case 1 where dataSource[section].isEmpty:
            return 1
        default:
            return dataSource[section].count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch (indexPath.section, indexPath.item) {
        case (0, 0):
            return collectionView.dequeueReusableCell(withClass: BlankCardCell.self, for: indexPath)
        case (1, 0) where dataSource[indexPath.section].isEmpty:
            return collectionView.dequeueReusableCell(withClass: BlankCardCell.self, for: indexPath)
        default:
            return collectionView.dequeueReusableCell(withClass: CardCell.self, for: indexPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        switch (indexPath.section, indexPath.item) {
        case (0, 0),
             (1, 0) where dataSource[indexPath.section].isEmpty:
            return false
        default:
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch kind {
        case UICollectionElementKindSectionHeader:
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withClass: CardHeaderCollectionReusableView.self, for: indexPath)
            view.textLabel.text = Mastered
            return view
        default:
            assert(false, "Unexpected header kind: \(kind)")
            return UICollectionReusableView()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        if section == 1 {
            return CGSize(width: 300, height: 60)
        }
        return CGSize.zero
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        
        guard let card = cardFor(sourceIndexPath) else { return }
        
        let destinationCardDataSource = dataSource[destinationIndexPath.section]
        var currentOrderArray = Array(destinationCardDataSource)
        
        if let cardToMoveIndex = currentOrderArray.index(of: card) {
            currentOrderArray.remove(at: cardToMoveIndex)
        }
        
        let adjustedIndex: Int
        switch (destinationIndexPath.section, destinationIndexPath.item) {
        case (0, 0),
             (1, 0) where dataSource[destinationIndexPath.section].isEmpty:
            adjustedIndex = 0
        case (0, let item) where item > 0:
            adjustedIndex = item - 1
        default:
            adjustedIndex = destinationIndexPath.item
        }
        
        currentOrderArray.insert(card, at: adjustedIndex)
        
        let realm = try! Realm()
        let date = Date()
        try? realm.write {
            currentOrderArray.enumerated().forEach { index, _card in
                _card.order = Float(index)
                _card.modified = date
            }
            card.mastered = destinationIndexPath.section == 0 ? nil : Date()
            card.modified = date
            if stack.preferences == nil {
                let prefs = StackPreferences(stack: stack)
                realm.add(prefs, update: true)
                stack.preferences = prefs
            }
            stack.preferences?.modified = date
        }
    }
}
