// Douglas Hill, May 2019

import UIKit

/// A collection view that supports navigation and selection using a hardware keyboard.
///
/// This class can be seen in action in the *List*, *Composition Layout* and *Flow Layout*
/// examples in the demo app.
///
/// Wrapping the selection on reaching the end of a row or column is only supported with `UICollectionViewFlowLayout`.
///
/// `UICollectionViewCompositionalLayout`’s `orthogonalScrollingBehavior` is not supported.
///
/// **Focus system**
///
/// KeyboardKit sets `allowsFocus` and `remembersLastFocusedIndexPath` to true by default,
/// so if a `UIFocusSystem` is available then UIKit will provide support for arrow key
/// navigation in the collection view.
///
/// If no `UIFocusSystem` is available then KeyboardKit fills in by providing similar
/// functionality as long as the collection view becomes first responder. In this case, it is
/// your app’s responsibility to manage which object is first responder. The item that the
/// user navigates to is modelled with the collection view selection state, not the focus state.
///
/// The focus system is available from iOS 15 on iPad and from iOS 14 on Mac (macOS 11 Big Sur
/// and later). As of iOS 15, the focus system is not available at all on iPhone.
///
/// Moving items with opt-cmd-arrow will act on the focused item if `UIFocusSystem` is
/// available and on the selected item otherwise.
///
/// **Reordering**
///
/// If the app enables reordering then KeyboardKit allows users to move items using
/// *option + command + arrow keys*. This will move the selected item into the position
/// of the closest item in the specified direction.
///
/// KeyboardKit’s support for reordering uses standard UIKit API. To enable reordering, the
/// collection view’s `dataSource` must implement `collectionView(_:moveItemAt:to:)`. To disable
/// moving certain items, the data source should implement `collectionView(_:canMoveItemAt:)`.
/// If this is not implemented then moving will be allowed. To alter the destination
/// index path of a move operation, the collection view’s `delegate` should implement
/// `collectionView(_:targetIndexPathForMoveFromItemAt:toProposedIndexPath:)`.
///
/// ⚠️ Moving items using a hardware keyboard is not supported when using a `UICollectionViewDiffableDataSource`.
///
/// Moving *sections* using a hardware keyboard is not supported.
///
/// The *Composition Layout* and *Flow Layout* examples in the demo app show reordering in action.
open class KeyboardCollectionView: UICollectionView, ResponderChainInjection {
    public override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        sharedInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        sharedInit()
    }

    private func sharedInit() {
#if !targetEnvironment(macCatalyst)
        if #available(iOS 15.0, *) {
            allowsFocus = true
            remembersLastFocusedIndexPath = true
        }
#endif
    }

    open override var canBecomeFirstResponder: Bool {
        true
    }

    private lazy var selectableCollectionKeyHandler = SelectableCollectionKeyHandler(selectableCollection: self, owner: self)
    private lazy var scrollViewKeyHandler = ScrollViewKeyHandler(scrollView: self, owner: self)

    open override var next: UIResponder? {
        selectableCollectionKeyHandler
    }

    func nextResponderForResponder(_ responder: UIResponder) -> UIResponder? {
        if responder === selectableCollectionKeyHandler {
            return scrollViewKeyHandler
        } else if responder === scrollViewKeyHandler {
            return super.next
        } else {
            preconditionFailure()
        }
    }
}

/// A collection view controller that supports navigation and selection using a hardware keyboard.
///
/// See `KeyboardCollectionView` for further details. There is no difference in
/// functionality between the view subclass and the view controller subclass.
open class KeyboardCollectionViewController: UICollectionViewController, ResponderChainInjection {
    open override var canBecomeFirstResponder: Bool {
        true
    }

    private lazy var selectableCollectionKeyHandler = SelectableCollectionKeyHandler(selectableCollection: collectionView, owner: self)
    private lazy var scrollViewKeyHandler = ScrollViewKeyHandler(scrollView: collectionView, owner: self)

    open override var next: UIResponder? {
        selectableCollectionKeyHandler
    }

    func nextResponderForResponder(_ responder: UIResponder) -> UIResponder? {
        if responder === selectableCollectionKeyHandler {
            return scrollViewKeyHandler
        } else if responder === scrollViewKeyHandler {
            return super.next
        } else {
            preconditionFailure()
        }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

#if !targetEnvironment(macCatalyst)
        if #available(iOS 15.0, *) {
            collectionView.allowsFocus = true
            collectionView.remembersLastFocusedIndexPath = true
        }
#endif
    }
}

/// A collection view’s `delegate` can conform to this protocol to receive callbacks about keyboard-specific events.
///
/// This can be used with either `KeyboardCollectionView` or `KeyboardCollectionViewController`.
///
/// When selection is activated with return or space, the regular delegate method `collectionView(_:didSelectItemAt:)` is called.
public protocol KeyboardCollectionViewDelegate: UICollectionViewDelegate {
    /// Called when a keyboard is used to change the selected items.
    ///
    /// This happens in response to arrow keys, escape and ⌘A.
    /// When there is a `UIFocusSystem`, this is only called for Select All (⌘A).
    /// The items show as selected but `collectionView(_:didSelectItemAt:)` is not
    /// called unless return or space is pressed while a single item shows selection.
    ///
    /// The new selected items can be read using `collectionView.indexPathsForSelectedItems`.
    ///
    /// Typically this callback would be used for changes in a collection view in a sidebar to update the
    /// content in a detail view. This callback should typically be ignored when a split view controller
    /// is collapsed because updating a detail view that isn’t visible may be wasteful.
    func collectionViewDidChangeSelectedItemsUsingKeyboard(_ collectionView: UICollectionView)

    /// Asks the delegate whether the selection is allowed to be cleared by pressing the escape key.
    ///
    /// This is not called when there is a `UIFocusSystem`.
    ///
    /// If not implemented, the collection view assumes it can clear the selection (i.e. this defaults to true).
    func collectionViewShouldClearSelectionUsingKeyboard(_ collectionView: UICollectionView) -> Bool
}

extension UICollectionView {
    override var kbd_isArrowKeyScrollingEnabled: Bool {
        isKeyboardScrollingEnabled
    }

    override var kbd_isSpaceBarScrollingEnabled: Bool {
        isKeyboardScrollingEnabled
    }
}

extension UICollectionView: SelectableCollection {
    private var keyboardDelegate: KeyboardCollectionViewDelegate? {
        delegate as? KeyboardCollectionViewDelegate
    }

    var allowsSelectionDuringEditing_: Bool {
        if #available(iOS 14.0, *) {
            return allowsSelectionDuringEditing
        } else {
            return false // Doesn’t matter because isEditing_ will always be false.
        }
    }

    var allowsMultipleSelectionDuringEditing_: Bool {
        if #available(iOS 14.0, *) {
            return allowsMultipleSelectionDuringEditing
        } else {
            return false // Doesn’t matter because isEditing_ will always be false.
        }
    }

    var isEditing_: Bool {
        if #available(iOS 14.0, *) {
            return isEditing
        } else {
            return false
        }
    }

    var shouldAllowEmptySelection: Bool? {
        // shouldDeselectItemAtIndexPath is not considered appropriate because it is explicitly documented as
        // “called when the user taps on an already-selected item in multi-select mode”
        // and also there is no equivalent for UITableView.
        keyboardDelegate?.collectionViewShouldClearSelectionUsingKeyboard(self)
    }

    func shouldSelectItemAtIndexPath(_ indexPath: IndexPath) -> Bool {
        delegate?.collectionView?(self, shouldHighlightItemAt: indexPath) ?? true
    }

    var indexPathsForFocusedOrSelectedItems: [IndexPath] {
        if UIFocusSystem(for: self) != nil {
            return preferredFocusEnvironments.compactMap { $0 as? UICollectionViewCell }.compactMap { indexPath(for: $0) }
        } else {
            return indexPathsForSelectedItems ?? []
        }
    }

    func notifyDelegateOfSelectionChange() {
        keyboardDelegate?.collectionViewDidChangeSelectedItemsUsingKeyboard(self)
    }

    func activateSelection(at indexPath: IndexPath) {
        delegate?.collectionView?(self, didSelectItemAt: indexPath)
    }

    func cellVisibility(atIndexPath indexPath: IndexPath) -> CellVisibility {

        // TODO: The use of frame likely gives incorrect results if there are transforms.

        // Note the force unwrapping. Not sure why this is nullable.
        let layoutAttributes = collectionViewLayout.layoutAttributesForItem(at: indexPath)!
        if bounds.inset(by: adjustedContentInset).contains(layoutAttributes.frame) {
            return .fullyVisible
        }

        var position: UICollectionView.ScrollPosition = []
        position.insert(layoutAttributes.frame.midY < bounds.midY ? .top : .bottom)
        position.insert(layoutAttributes.frame.midX < bounds.midX ? .left : .right)

        return .notFullyVisible(position)
    }

    func indexPathFromIndexPath(_ indexPath: IndexPath?, inDirection direction: NavigationDirection, step: NavigationStep) -> IndexPath? {
        collectionViewLayout.kbd_indexPathFromIndexPath(indexPath, inDirection: direction.rawValue, step: step.rawValue)
    }

    var shouldAllowMoving: Bool {
        guard let dataSource = dataSource else {
            return false
        }
        /*
         Diff-able data sources are not supported. Several factors make this very difficult to support.

         Firstly, can’t call `moveItem(at:to:)` on a collection view using a diff-able data source. Doing so results in

         *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason:
         'UICollectionView must be updated via the UICollectionViewDiffableDataSource APIs when acting
         as the UICollectionView's dataSource: please do not call mutation APIs directly on UICollectionView.

         This makes sense but means KeyboardKit needs to detect this case so it can use the diff-able data source API
         instead. (And call the reordering handlers to let the app know about the change.)

         However the diff-able data source type is generic in Swift and the way generics work in Swift there is no
         way to cast to a generic type. You need to know the specialised type, and KeyboardKit couldn’t do this
         without adding some API that apps need to use. Something like making KeyboardCollectionView and
         KeyboardCollectionViewController generic or have a generic property. It sounds annoying to deal with.

         An additional complication is that the diff-able data source API is different in Swift and Objective-C.
         You end up with a different class as the data source depending on which language you use to create it.

         So KeyboardKit would need three implementations of moving: regular data source, Objective-C diff-able data source,
         and Swift diff-able data source. The Swift one could not work out-of-the-box.

         In Swift, the Swift one is called `UICollectionViewDiffableDataSource<SectionIdentifierType, ItemIdentifierType>`.
         In Objective-C, the Swift one is called `_TtGC5UIKit34UICollectionViewDiffableDataSourceSiSS_`.
         In Objective-C, the Objective-C one is called `UICollectionViewDiffableDataSource`.
         In Swift, the Objective-C one is called `UICollectionViewDiffableDataSourceReference`.

         We check the type using the Objective-C runtime, so we need to search for the name as it appears in Objective-C.
         */
        if NSStringFromClass(type(of: dataSource)).contains("UICollectionViewDiffableDataSource") {
            return false
        }
        return dataSource.responds(to: #selector(UICollectionViewDataSource.collectionView(_:moveItemAt:to:)))
    }

    func canMoveItem(at indexPath: IndexPath) -> Bool? {
        dataSource!.collectionView?(self, canMoveItemAt: indexPath)
    }

    func targetIndexPathForMoveFromItem(at originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath? {
        delegate?.collectionView?(self, targetIndexPathForMoveFromItemAt: originalIndexPath, toProposedIndexPath: proposedIndexPath)
    }

    func kdb_moveItem(at indexPath: IndexPath, to newIndexPath: IndexPath) {
        // It is important to update the data source first otherwise you can end up ‘duplicating’ the cell being moved when moving quickly at the edges.
        // nil data source and not implementing method was checked in canMoveItem so force here.
        dataSource!.collectionView!(self, moveItemAt: indexPath, to: newIndexPath)
        moveItem(at: indexPath, to: newIndexPath)
    }
}

private extension UICollectionViewLayout {

    /// Maps from an old selected index path to a new selected index path by moving by the given step in the given direction.
    ///
    /// `UICollectionViewLayout` implements this method in a spatial manner. Subclasses may override this to provide better handling. Calling super is not necessary.
    ///
    /// This needs to use `@objc` so it can be overridden by subclasses. This means that Swift enums can’t be used as parameters, so pass around integers. Bridging at its best!
    ///
    /// - Parameters:
    ///   - indexPath: The existing selected index path if there is one.
    ///   - rawDirection: The direction in which to move the selection. The value is the raw representation of a `NavigationDirection`.
    ///   - rawStep: The step by which to move the selection. The value is the raw representation of a `NavigationStep`.
    ///   - keyHandler: The key handler. Provided to do index path operations like finding the first selectable index path.
    ///
    /// - Returns: The adjusted index path or nil if no appropriate index path exists.
    @objc func kbd_indexPathFromIndexPath(_ indexPath: IndexPath?, inDirection rawDirection: Int, step rawStep: Int) -> IndexPath? {
        let direction = NavigationDirection(rawValue: rawDirection)!
        let step = NavigationStep(rawValue: rawStep)!

        guard
            let oldIndexPath = indexPath,
            let attributesOfOldSelection = layoutAttributesForItem(at: oldIndexPath)
        else {
            /*
             It’s very layout-dependent what would make sense here. Important to not always return nil otherwise it would
             be impossible to get started with arrow key navigation. Doing this spatially would mean looking for items
             closest to an edge. This potentially means requesting all layout attributes (as in the case of pressing left
             or right in a list). This could be expensive and not make sense to the user anyway.
             */

            /*
             This behaviour is modified for compositional layout so that the initial selection is only created in the
             scroll direction. I.e. so left/right arrows keys don’t make an initial selection in a list.

             Ideally this method would be overridden by `UICollectionViewCompositionalLayout`. That class is only
             available from iOS 13 while our deployment target is currently iOS 12, so the extension must be
             marked with `@available(iOS 13.0, *)`. (I guess that’s just to be explicit. This could surely be
             inferred.) However for some reason if the extension on `UICollectionViewCompositionalLayout` has an
             `@available` restriction then we get this compiler error:

             > Overriding 'kbd_indexPathFromIndexPath' must be as available as declaration it overrides

             I don’t understand why that would be the case. Isn’t doing stuff like this the point of dynamic dispatch?
             Rewriting all this index path moving code in Objective-C would be tedious because there are lots of switch
             statements on tuples. So let’s just check for the specific subclass here instead of using overriding.
             */

            if #available(iOS 13.0, *), let compositionalLayout = self as? UICollectionViewCompositionalLayout {
                switch compositionalLayout.configuration.scrollDirection {
                case .horizontal:
                    switch (direction, collectionView!.effectiveUserInterfaceLayoutDirection) {
                    case (.up, _), (.down, _):
                        return nil
                    case (.left, .leftToRight), (.right, .rightToLeft):
                        return collectionView!.lastSelectableIndexPath
                    case (.right, .leftToRight), (.left, .rightToLeft):
                        return collectionView!.firstSelectableIndexPath
                    @unknown default:
                        break
                    }
                case .vertical:
                    switch direction {
                    case .left, .right:
                        return nil
                    case .up:
                        return collectionView!.lastSelectableIndexPath
                    case .down:
                        return collectionView!.firstSelectableIndexPath
                    }
                @unknown default:
                    break
                }
            }

            // We have no idea so always go to the first item.
            // A possible improvement would be to infer the scroll direction for custom layouts based on the
            // collectionViewContentSize and then use the same branching as for compositional layout above.
            return collectionView!.firstSelectableIndexPath
        }

        if let newIndexPath = indexPathBySearchingFromAttributes(attributesOfOldSelection, direction: direction, step: step) {
            return newIndexPath
        }

        switch step {
        case .end, .closestForMoving:
            // Already at end so can’t do any more.
            return nil
        case .closest:
            // Wrap around.
            let newIndexPath = indexPathBySearchingFromAttributes(attributesOfOldSelection, direction: direction.opposite, step: .end)
            // If we wrapped around to the same object, return nil so we don’t steal this event without doing anything.
            return newIndexPath == indexPath ? nil : newIndexPath
        }
    }

    private func indexPathBySearchingFromAttributes(_ attributesOfOldSelection: UICollectionViewLayoutAttributes, direction: NavigationDirection, step: NavigationStep) -> IndexPath? {
        // First search some small distance along. Likely to find something. Feels like it might be faster than searching a long way from the start. Haven’t tested the performance; it depends so much on the layout anyway.
        if let newIndexPath = indexPathBySearchingFromAttributes(attributesOfOldSelection, direction: direction, step: step, offset: 0, distance: 500) {
            return newIndexPath
        }

        // Search further if nothing was found. Assume we’re at the end if the next item is further than 3000 points away.
        return indexPathBySearchingFromAttributes(attributesOfOldSelection, direction: direction, step: step, offset: 500, distance: 2500)
    }

    private func indexPathBySearchingFromAttributes(_ attributesOfOldSelection: UICollectionViewLayoutAttributes, direction: NavigationDirection, step: NavigationStep,  offset: CGFloat, distance distanceToSearch: CGFloat) -> IndexPath? {
        let rectangleOfOldSelection = attributesOfOldSelection.frame
        let centreOfOldSelection = attributesOfOldSelection.center
        let contentSize = collectionViewContentSize

        var resolvedDirection = direction

        /*
         Automatic flipping works with some kind of coordinate space magic. It’s easiest to flip the search direction by flipping the navigation direction.

         UICollectionViewCompositionalLayout seems to have a special case where it flips by default when in a right-to-left environment.
         Here’s a little table of what it does (tested on iOS 14.3):

         flipsHorizontallyInOppositeLayoutDirection |  no  yes   no  yes     no  yes   no  yes
         developmentLayoutDirection                 |  ->   ->   <-   <-     ->   ->   <-   <-
         effectiveUserInterfaceLayoutDirection      |  ->   ->   ->   ->     <-   <-   <-   <-
         ------------------------------------------ | ----------------------------------------
         ends up flipping?                          |  no   no   no  yes    yes  yes   no   no

         The ‘if else if’ below effectively comprises an OR, but that’s hard/impossible to express in one condition with the availability check.
         */
        if flipsHorizontallyInOppositeLayoutDirection && collectionView!.effectiveUserInterfaceLayoutDirection != developmentLayoutDirection {
            resolvedDirection = resolvedDirection.flippedHorizontally
        } else if #available(iOS 13.0, *),
                  self is UICollectionViewCompositionalLayout,
                  developmentLayoutDirection == .leftToRight,
                  collectionView!.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            resolvedDirection = resolvedDirection.flippedHorizontally
        }

        let rectangleToSearch: CGRect
        switch (resolvedDirection, step) {

        case (.up, .closest), (.up, .closestForMoving):
            rectangleToSearch = CGRect(x: rectangleOfOldSelection.minX, y: rectangleOfOldSelection.midY - offset - distanceToSearch, width: rectangleOfOldSelection.width, height: distanceToSearch)
        case (.down, .end):
            rectangleToSearch = CGRect(x: rectangleOfOldSelection.minX, y: contentSize.height - offset - distanceToSearch, width: rectangleOfOldSelection.width, height: distanceToSearch)

        case (.down, .closest), (.down, .closestForMoving):
            rectangleToSearch = CGRect(x: rectangleOfOldSelection.minX, y: rectangleOfOldSelection.midY + offset, width: rectangleOfOldSelection.width, height: distanceToSearch)
        case (.up, .end):
            rectangleToSearch = CGRect(x: rectangleOfOldSelection.minX, y: 0 + offset, width: rectangleOfOldSelection.width, height: distanceToSearch)

        case (.left, .closest), (.left, .closestForMoving):
            rectangleToSearch = CGRect(x: rectangleOfOldSelection.midX - offset - distanceToSearch, y: rectangleOfOldSelection.minY, width: distanceToSearch, height: rectangleOfOldSelection.height)
        case (.right, .end):
            rectangleToSearch = CGRect(x: contentSize.width - offset - distanceToSearch, y: rectangleOfOldSelection.minY, width: distanceToSearch, height: rectangleOfOldSelection.height)

        case (.right, .closest), (.right, .closestForMoving):
            rectangleToSearch = CGRect(x: rectangleOfOldSelection.midX + offset, y: rectangleOfOldSelection.minY, width: distanceToSearch, height: rectangleOfOldSelection.height)
        case (.left, .end):
            rectangleToSearch = CGRect(x: 0 + offset, y: rectangleOfOldSelection.minY, width: distanceToSearch, height: rectangleOfOldSelection.height)
        }

        let attributesArray = layoutAttributesForElements(in: rectangleToSearch) ?? []

        var closestAttributes: UICollectionViewLayoutAttributes?
        var smallestDistance = CGFloat.greatestFiniteMagnitude
        /// Used if two or more items are the same distance away in the desired direction. Most commonly, this kicks
        /// in when a grid has no padding between items. Transverse means the direction perpendicular to `direction`.
        var smallestTransverseDistance = CGFloat.greatestFiniteMagnitude

        for attributes in attributesArray {
            guard attributes.isHidden == false
                    && attributes.alpha > 0
                    && attributes.representedElementCategory == .cell
                    // For moving the destination does not need to be selectable. For selection it obviously does.
                    && (step == .closestForMoving || collectionView!.shouldSelectItemAtIndexPath(attributes.indexPath))
            else {
                continue
            }

            let distance: CGFloat
            switch (resolvedDirection, step) {
            case (.up, .closest), (.up, .closestForMoving):
                distance = centreOfOldSelection.y - attributes.center.y
            case (.down , .end):
                distance = contentSize.height - attributes.center.y

            case (.down, .closest), (.down, .closestForMoving):
                distance = attributes.center.y - centreOfOldSelection.y
            case (.up , .end):
                distance = attributes.center.y - 0

            case (.left, .closest), (.left, .closestForMoving):
                distance = centreOfOldSelection.x - attributes.center.x
            case (.right , .end):
                distance = contentSize.width - attributes.center.x

            case (.right, .closest), (.right, .closestForMoving):
                distance = attributes.center.x - centreOfOldSelection.x
            case (.left , .end):
                distance = attributes.center.x
            }

            guard distance > 0 else {
                // Most likely this is the old selected item or one transverse to it. This could also be one slightly
                // in the opposite direction, or the layout returned attributes outside of what we asked for.
                continue
            }

            let transverseDistance: CGFloat
            switch resolvedDirection {
            case .up, .down: transverseDistance = abs(attributes.center.x - centreOfOldSelection.x)
            case .left, .right: transverseDistance = abs(attributes.center.y - centreOfOldSelection.y)
            }

            // The ‘sort descriptors’ are [distance, transverse distance, index path]. The index path is a deterministic tie-breaker.
            if distance < smallestDistance || distance == smallestDistance && (transverseDistance < smallestTransverseDistance || transverseDistance == smallestTransverseDistance && attributes.indexPath < closestAttributes!.indexPath) {
                closestAttributes = attributes
                smallestDistance = distance
                smallestTransverseDistance = transverseDistance
            }
        }

        return closestAttributes?.indexPath
    }
}

private extension UICollectionViewFlowLayout {
    /// Overridden so that wrapping around moves to the next/previous line instead of the start/end of the current line.
    override func kbd_indexPathFromIndexPath(_ indexPath: IndexPath?, inDirection rawDirection: Int, step rawStep: Int) -> IndexPath? {
        let direction = NavigationDirection(rawValue: rawDirection)!

        enum UpdateBehaviour {
            case spatial
            case forwards
            case backwards
        }

        /*
         UICollectionViewFlowLayout seems to handle right-to-left differently to normal. It seems to always follow the layout
         direction unless flipsHorizontallyInOppositeLayoutDirection is true and developmentLayoutDirection is right-to-left.

         Given that the spatial behaviour from the superclass implementation works fine, I think the underlying coordinate spaces
         behave as normal, which is means the logic in flow layout is probably un-flipping CV’s flipping in some cases.

         Here’s a table of how the layout direction ends up (tested on iOS 14.3):

         flipsHorizontallyInOppositeLayoutDirection |  no  yes   no  yes     no  yes   no  yes     no  yes   no  yes     no  yes   no  yes
         developmentLayoutDirection                 |  ->   ->   <-   <-     ->   ->   <-   <-     ->   ->   <-   <-     ->   ->   <-   <-
         effectiveUserInterfaceLayoutDirection      |  ->   ->   ->   ->     <-   <-   <-   <-     ->   ->   ->   ->     <-   <-   <-   <-
         scrollDirection                            |  ↕︎    ↕︎    ↕︎    ↕︎      ↕︎    ↕︎    ↕︎    ↕︎     <->  <->  <->  <->    <->  <->  <->  <->
         ------------------------------------------ | ------------------------------------------------------------------------------------
         ends up with layout direction              |  ->   ->   ->   <-     <-   <-   <-   ->     ->   ->   ->   <-    (*)   <-  (*)   ->

         (*) The layout is arranged left-to-right but scrolling is set up for right-to-left (i.e. it starts at the far right end).
         */
        let actualLayoutDirection: UIUserInterfaceLayoutDirection
        if flipsHorizontallyInOppositeLayoutDirection && developmentLayoutDirection == .rightToLeft {
            actualLayoutDirection = collectionView!.effectiveUserInterfaceLayoutDirection.flipped
        } else {
            actualLayoutDirection = collectionView!.effectiveUserInterfaceLayoutDirection
        }

        var updateBehaviour: UpdateBehaviour {
            switch (scrollDirection, direction) {
            case (.horizontal, .up):
                return .backwards
            case (.horizontal, .down):
                return .forwards
            case (.vertical, .left):
                return actualLayoutDirection == .rightToLeft ? .forwards : .backwards
            case (.vertical, .right):
                return actualLayoutDirection == .rightToLeft ? .backwards : .forwards
            case (.vertical, .up), (.vertical, .down), (.horizontal, .left), (.horizontal, .right):
                return .spatial
            @unknown default:
                return .spatial
            }
        }

        switch (updateBehaviour, NavigationStep(rawValue: rawStep)!) {

        case (.spatial, _), (_, .end):
            return super.kbd_indexPathFromIndexPath(indexPath, inDirection: rawDirection, step: rawStep)

        case (.backwards, .closest):
            // Select the first highlightable item before the current selection, or select the last highlightable
            // item if there is no current selection or if the current selection is the first highlightable item.
            if let indexPath = indexPath, let target = collectionView!.selectableIndexPathBeforeIndexPath(indexPath) {
                return target
            } else {
                return collectionView!.lastSelectableIndexPath
            }

        case (.backwards, .closestForMoving):
            return collectionView!.indexPathToMoveToBeforeIndexPath(indexPath!)

        case (.forwards, .closest):
            // Select the first highlightable item after the current selection, or select the first highlightable
            // item if there is no current selection or if the current selection is the last highlightable item.
            if let indexPath = indexPath, let target = collectionView!.selectableIndexPathAfterIndexPath(indexPath) {
                return target
            } else {
                return collectionView!.firstSelectableIndexPath
            }

        case (.forwards, .closestForMoving):
            return collectionView!.indexPathToMoveToAfterIndexPath(indexPath!)
        }
    }
}

private extension UIUserInterfaceLayoutDirection {
    var flipped: UIUserInterfaceLayoutDirection {
        switch self {
        case .leftToRight: return .rightToLeft
        case .rightToLeft: return .leftToRight
        @unknown default: return self
        }
    }
}

private extension NavigationDirection {
    var opposite: NavigationDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    var flippedHorizontally: NavigationDirection {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .right
        case .right: return .left
        }
    }
}
