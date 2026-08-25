import SwiftUI

struct CreateProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var kind: ProgramKind = .strongLifts
    @State private var name = ""
    @State private var editingProgram: Program?
    let onCreate: (Program) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Program type") {
                    Picker("Type", selection: $kind) {
                        ForEach(ProgramKind.allCases) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Name") { TextField("Program name", text: $name) }
                Section { Text(kind == .strongLifts ? "Starts with protected Workout A/B identities." : "Starts with a valid 3-day ATG schedule; edit it before saving.").font(.caption).foregroundStyle(.secondary) }
            }
            .navigationTitle("Create Program")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { editingProgram = Program.new(kind: kind, name: name) }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(item: $editingProgram) { program in
                ProgramEditorView(program: program) { saved in
                    onCreate(saved)
                    dismiss()
                }
            }
        }
    }
}
