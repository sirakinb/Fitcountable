import SwiftUI
import UIKit

extension Color {
    static let fitGreen = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.34, green: 0.91, blue: 0.58, alpha: 1)
            : UIColor(red: 0.25, green: 0.82, blue: 0.48, alpha: 1)
    })
    static let fitBlue = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.38, green: 0.62, blue: 1.00, alpha: 1)
            : UIColor(red: 0.15, green: 0.45, blue: 0.95, alpha: 1)
    })
    static let fitInk = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.97, blue: 0.96, alpha: 1)
            : UIColor(red: 0.06, green: 0.08, blue: 0.09, alpha: 1)
    })
    static let fitMuted = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.67, green: 0.72, blue: 0.71, alpha: 1)
            : UIColor(red: 0.45, green: 0.48, blue: 0.50, alpha: 1)
    })
    static let fitSurface = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.06, blue: 0.06, alpha: 1)
            : UIColor(red: 0.95, green: 0.97, blue: 0.96, alpha: 1)
    })
    static let fitMist = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.12, blue: 0.13, alpha: 1)
            : UIColor(red: 0.88, green: 0.95, blue: 0.99, alpha: 1)
    })
    static let fitCard = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.13, blue: 0.13, alpha: 1)
            : UIColor.white
    })
    static let fitBorder = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.10)
            : UIColor(white: 0.0, alpha: 0.06)
    })
}

private struct FitCardSurface: ViewModifier {
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Color.fitCard, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.fitBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 14, y: 6)
    }
}

extension View {
    func fitCardSurface(cornerRadius: CGFloat = 18) -> some View {
        modifier(FitCardSurface(cornerRadius: cornerRadius))
    }
}

struct EmptyStateCard: View {
    var systemImage: String
    var title: String
    var subtitle: String
    var tint: Color = .fitBlue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(tint)
                .frame(width: 52, height: 52)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.fitMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fitCardSurface()
    }
}

struct FitPressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

@MainActor
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct ProfilePhotoView: View {
    var imageData: Data?
    var imageURL: URL? = nil
    var fallback: String
    var size: CGFloat
    var color: Color = .fitBlue

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let data = imageURL?.dataURLImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        fallbackCircle
                    }
                }
            } else {
                fallbackCircle
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var fallbackCircle: some View {
        Circle()
            .fill(color.opacity(0.14))
            .overlay(Text(String(fallback.prefix(1))).font(.headline.bold()).foregroundStyle(color))
    }
}

extension URL {
    var dataURLImageData: Data? {
        guard absoluteString.hasPrefix("data:"),
              let commaIndex = absoluteString.firstIndex(of: ",") else {
            return nil
        }
        let encoded = String(absoluteString[absoluteString.index(after: commaIndex)...])
        return Data(base64Encoded: encoded)
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var detail: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
                .tracking(0.6)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .black))
                .foregroundStyle(Color.fitInk)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.fitMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    var title: String
    var action: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            if let action {
                Text(action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.fitBlue)
            }
        }
    }
}

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "arrow.right")
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.fitGreen, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: Color.fitGreen.opacity(isEnabled ? 0.28 : 0), radius: 12, y: 6)
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(FitPressableButtonStyle())
    }
}
