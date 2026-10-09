import UIKit

/// Long-press accent row. Selection follows the finger 1:1 (§7 direct manipulation).
final class AccentPickerView: UIView {
    private var labels: [UILabel] = []
    private(set) var options: [String] = []
    private(set) var selectedIndex = 0
    private let cellWidth: CGFloat = 34

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyCapView.characterColor
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 3
        isUserInteractionEnabled = false
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var selected: String? { options.indices.contains(selectedIndex) ? options[selectedIndex] : nil }

    func show(options: [String], above keyFrame: CGRect, in container: CGRect) {
        self.options = options
        labels.forEach { $0.removeFromSuperview() }
        labels = options.map { text in
            let l = UILabel()
            l.text = text
            l.font = .systemFont(ofSize: 24)
            l.textAlignment = .center
            l.layer.cornerRadius = 6
            l.layer.cornerCurve = .continuous
            l.clipsToBounds = true
            addSubview(l)
            return l
        }
        let width = cellWidth * CGFloat(options.count) + 8
        var frame = CGRect(x: keyFrame.minX - 4, y: keyFrame.minY - 52, width: width, height: 48)
        frame.origin.x = min(max(frame.minX, container.minX + 2), container.maxX - width - 2)
        self.frame = frame
        for (i, l) in labels.enumerated() {
            l.frame = CGRect(x: 4 + CGFloat(i) * cellWidth, y: 4, width: cellWidth, height: 40)
        }
        select(index: 0)
        isHidden = false
    }

    func updateSelection(forX x: CGFloat) {
        let local = x - frame.minX - 4
        select(index: min(max(Int(local / cellWidth), 0), options.count - 1))
    }

    func hide() { isHidden = true; options = [] }

    private func select(index: Int) {
        selectedIndex = index
        for (i, l) in labels.enumerated() {
            l.backgroundColor = i == index ? .systemBlue : .clear
            l.textColor = i == index ? .white : .label
        }
    }
}
