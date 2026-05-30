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

struct ProfilePhotoView: View {
    var imageData: Data?
    var fallback: String
    var size: CGFloat
    var color: Color = .fitBlue

    var body: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(color.opacity(0.14))
                    .overlay(Text(String(fallback.prefix(1))).font(.headline.bold()).foregroundStyle(color))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

struct MetricCard: View {
    var title: String
    var value: String
    var detail: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.fitMuted)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(Color.fitInk)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(Color.fitMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.fitBorder, lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    var title: String
    var action: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
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

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage ?? "arrow.right")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.fitGreen)
        .controlSize(.large)
    }
}
