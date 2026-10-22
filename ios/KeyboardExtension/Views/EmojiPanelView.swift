import UIKit

/// Emoji picker shown in place of the keys (custom keyboards can't open the system emoji keyboard).
/// Horizontal pages by category like the system one, with recents first and ABC / categories / delete at the bottom.
final class EmojiPanelView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onEmoji: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onKeyDown: (() -> Void)?

    private struct Category { let title: String; let symbol: String; var emojis: [String] }

    private static let recentsKey = "recentEmojis"
    private static let maxRecents = 32
    private static let rows = 5

    private var categories: [Category] = []
    private let titleLabel = UILabel()
    private let collection: UICollectionView
    private let layout = UICollectionViewFlowLayout()
    private let bottomBar = UIStackView()
    private let abcButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let categoryStack = UIStackView()
    private var categoryButtons: [UIButton] = []

    override init(frame: CGRect) {
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        addSubview(titleLabel)

        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.delegate = self
        collection.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.id)
        addSubview(collection)

        abcButton.setTitle("ABC", for: .normal)
        abcButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        abcButton.tintColor = .label
        abcButton.accessibilityLabel = "Voltar às letras"
        abcButton.addAction(UIAction { [weak self] _ in
            self?.onKeyDown?()
            self?.onDismiss?()
        }, for: .touchUpInside)

        deleteButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        deleteButton.tintColor = .label
        deleteButton.accessibilityLabel = "Apagar"
        deleteButton.addAction(UIAction { [weak self] _ in
            self?.onKeyDown?()
            self?.onDelete?()
        }, for: .touchUpInside)

        categoryStack.distribution = .fillEqually
        bottomBar.addArrangedSubview(abcButton)
        bottomBar.addArrangedSubview(categoryStack)
        bottomBar.addArrangedSubview(deleteButton)
        bottomBar.spacing = 4
        abcButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        deleteButton.widthAnchor.constraint(equalToConstant: 48).isActive = true
        addSubview(bottomBar)
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reload() {
        let recents = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        categories = EmojiCatalog.categories.map { Category(title: $0.title, symbol: $0.symbol, emojis: $0.emojis) }
        categories.insert(Category(title: "UTILIZADOS FREQUENTEMENTE", symbol: "clock", emojis: recents), at: 0)
        rebuildCategoryButtons()
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
        updateTitle()
    }

    private func rebuildCategoryButtons() {
        categoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        categoryButtons = categories.enumerated().map { index, category in
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: category.symbol,
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)), for: .normal)
            button.tintColor = .secondaryLabel
            button.accessibilityLabel = category.title.capitalized
            button.addAction(UIAction { [weak self] _ in self?.scroll(toSection: index) }, for: .touchUpInside)
            categoryStack.addArrangedSubview(button)
            return button
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight: CGFloat = 36
        let titleHeight: CGFloat = 22
        titleLabel.frame = CGRect(x: 14, y: 2, width: bounds.width - 28, height: titleHeight)
        collection.frame = CGRect(x: 0, y: titleHeight, width: bounds.width, height: bounds.height - titleHeight - barHeight)
        bottomBar.frame = CGRect(x: 6, y: bounds.height - barHeight, width: bounds.width - 12, height: barHeight)
        let side = collection.bounds.height / CGFloat(Self.rows)
        layout.itemSize = CGSize(width: side, height: side)
        layout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        layout.invalidateLayout()
    }

    // MARK: Data source

    func numberOfSections(in collectionView: UICollectionView) -> Int { categories.count }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        categories[section].emojis.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.id, for: indexPath) as! EmojiCell
        cell.emoji = categories[indexPath.section].emojis[indexPath.item]
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let emoji = categories[indexPath.section].emojis[indexPath.item]
        onKeyDown?()
        onEmoji?(emoji)
        remember(emoji)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) { updateTitle() }

    // MARK: Helpers

    private func scroll(toSection section: Int) {
        guard categories.indices.contains(section) else { return }
        if categories[section].emojis.isEmpty {
            collection.setContentOffset(.zero, animated: false)
        } else {
            collection.scrollToItem(at: IndexPath(item: 0, section: section), at: .left, animated: false)
        }
        updateTitle()
    }

    private func updateTitle() {
        let probe = CGPoint(x: collection.contentOffset.x + 20, y: collection.bounds.midY)
        let section = collection.indexPathForItem(at: probe)?.section
            ?? collection.indexPathsForVisibleItems.map(\.section).min() ?? 0
        guard categories.indices.contains(section) else { return }
        titleLabel.text = categories[section].title
        for (i, button) in categoryButtons.enumerated() {
            button.tintColor = i == section ? .label : .secondaryLabel
        }
    }

    /// Recents are only reordered on the next reload so the grid doesn't jump under the finger.
    private func remember(_ emoji: String) {
        var recents = UserDefaults.standard.stringArray(forKey: Self.recentsKey) ?? []
        recents.removeAll { $0 == emoji }
        recents.insert(emoji, at: 0)
        UserDefaults.standard.set(Array(recents.prefix(Self.maxRecents)), forKey: Self.recentsKey)
    }
}

private final class EmojiCell: UICollectionViewCell {
    static let id = "EmojiCell"
    private let label = UILabel()

    var emoji: String = "" {
        didSet {
            label.text = emoji
            accessibilityLabel = emoji
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.font = .systemFont(ofSize: 30)
        label.textAlignment = .center
        contentView.addSubview(label)
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }

    override var isHighlighted: Bool {
        didSet {
            contentView.backgroundColor = isHighlighted ? UIColor.label.withAlphaComponent(0.12) : .clear
            contentView.layer.cornerRadius = 8
        }
    }
}
