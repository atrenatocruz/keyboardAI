import UIKit

/// Enlarged callout shown above a pressed character key (instant, no animation — §7).
final class KeyPopupView: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = KeyCapView.characterColor
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 2
        layer.shadowOffset = CGSize(width: 0, height: 1)
        label.font = .systemFont(ofSize: 32)
        label.textAlignment = .center
        label.textColor = .label
        addSubview(label)
        isUserInteractionEnabled = false
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(text: String, above keyFrame: CGRect, in container: CGRect) {
        label.text = text
        let width = max(keyFrame.width + 16, 44)
        var frame = CGRect(x: keyFrame.midX - width / 2, y: keyFrame.minY - 56, width: width, height: 54)
        frame.origin.x = min(max(frame.minX, container.minX + 2), container.maxX - width - 2)
        self.frame = frame
        label.frame = bounds
        isHidden = false
    }

    func hide() { isHidden = true }
}
