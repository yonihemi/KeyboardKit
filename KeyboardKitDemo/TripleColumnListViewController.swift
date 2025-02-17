// Douglas Hill, August 2020

import UIKit
import KeyboardKit

/// Shows a list of static strings set using the `items` property.
///
/// Intended for private use in `TripleColumnSplitViewController`.
class TripleColumnListViewController: FirstResponderViewController, KeyboardCollectionViewDelegate {
    init(appearance: UICollectionLayoutListConfiguration.Appearance) {
        self.appearance = appearance

        super.init()
    }

    /// The data displayed by the list as an array of the text for each item.
    var items: [String] = [] {
        didSet {
            if let dataSource = dataSource {
                reloadDataWithDataSource(dataSource)
            }
        }
    }

    /// The delegate to be notified when the selection changes in the list.
    weak var delegate: TripleColumnListViewControllerDelegate?

    /// The list appearance passed at initialisation.
    let appearance: UICollectionLayoutListConfiguration.Appearance
    private var dataSource: UICollectionViewDiffableDataSource<Int, String>? = nil

    /// The index of the selected item in the list.
    var selectedIndex = 0

    private lazy var collectionView = KeyboardCollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout.list(using: .init(appearance: appearance)))

    override func loadView() {
        // If the collection view starts off with zero frame is briefly shows as black when appearing.
        // I’ve only seen this happen with lists using UICollectionView, not in other compositional layouts.
        super.loadView() // Hack: Load the default view to get the initial frame from UIKit.
        let initialFrame = view.frame
        view = collectionView
        collectionView.frame = initialFrame
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self

        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewListCell, String> { cell, indexPath, stringItem in
            cell.contentConfiguration = {
                var config = cell.defaultContentConfiguration()
                config.text = stringItem
                config.secondaryText = "The detail text goes here."
                config.image = UIImage(systemName: "star")
                return config
            }()

            cell.accessories = [.disclosureIndicator()]
        }

        let dataSource = UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { collectionView, indexPath, identifier in
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
        }

        reloadDataWithDataSource(dataSource)

        self.dataSource = dataSource
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.selectItem(at: IndexPath(item: selectedIndex, section: 0), animated: false, scrollPosition: [])
    }

    private func reloadDataWithDataSource(_ dataSource: UICollectionViewDiffableDataSource<Int, String>) {
        dataSource.apply({
            var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
            snapshot.appendSections([0])
            snapshot.appendItems(items)
            return snapshot
        }(), animatingDifferences: false)
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedIndex = indexPath.item
        delegate?.didChangeSelectedItemsInListViewController(self, isExplicitActivation: true)
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn focusUpdateContext: UICollectionViewFocusUpdateContext, with animationCoordinator: UIFocusAnimationCoordinator) {
        guard let indexPath = focusUpdateContext.nextFocusedIndexPath, indexPath.item != selectedIndex else {
            return
        }

        selectedIndex = indexPath.item
        // Keep the selection in sync with focus without using selectionFollowsFocus since that would make columns hide and show.
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        delegate?.didChangeSelectedItemsInListViewController(self, isExplicitActivation: false)
    }

    // MARK: - KeyboardCollectionViewDelegate

    func collectionViewDidChangeSelectedItemsUsingKeyboard(_ collectionView: UICollectionView) {
        selectedIndex = collectionView.indexPathsForSelectedItems?.first?.item ?? 0
        delegate?.didChangeSelectedItemsInListViewController(self, isExplicitActivation: false)
    }

    func collectionViewShouldClearSelectionUsingKeyboard(_ collectionView: UICollectionView) -> Bool {
        // For this demo, we require all three lists to always have a selection.
        false
    }
}

// MARK: -

/// An object to be notified of selection changes in a list.
protocol TripleColumnListViewControllerDelegate: NSObjectProtocol {
    func didChangeSelectedItemsInListViewController(_ listViewController: TripleColumnListViewController, isExplicitActivation: Bool)
}
