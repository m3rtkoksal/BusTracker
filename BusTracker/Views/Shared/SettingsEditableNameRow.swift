import SwiftUI

struct SettingsEditableNameRow: View {
    let title: String
    @Binding var value: String
    let onSave: (String) -> Void
    
    @State private var isEditing = false
    @State private var editText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(NeonTheme.onSurfaceVariant)
            
            Spacer()
            
            if isEditing {
                TextField("", text: $editText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NeonTheme.onSurface)
                    .multilineTextAlignment(.trailing)
                    .focused($isFocused)
                    .onSubmit {
                        saveAndClose()
                    }
            } else {
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(NeonTheme.onSurface)
            }
            
            Image(systemName: isEditing ? "checkmark" : "pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NeonTheme.secondary)
        }
        .padding(16)
        .background(NeonTheme.surfaceContainer)
        .overlay {
            Rectangle()
                .strokeBorder(isEditing ? NeonTheme.secondary : NeonTheme.outline.opacity(0.3), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditing {
                saveAndClose()
            } else {
                editText = value
                isEditing = true
                isFocused = true
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused && isEditing {
                saveAndClose()
            }
        }
    }
    
    private func saveAndClose() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != value {
            onSave(trimmed)
        }
        isEditing = false
        isFocused = false
    }
}
