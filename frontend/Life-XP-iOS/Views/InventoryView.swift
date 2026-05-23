import SwiftUI

struct InventoryView: View {
    @ObservedObject var viewModel: UserViewModel
    @State private var showingShop = false

    var body: some View {
        NavigationView {
            VStack {
                // Header with Gold
                HStack {
                    Image(systemName: "banknote.fill")
                        .foregroundColor(.green)
                    Text("\(viewModel.user.gold) Gold")
                        .font(.headline)
                    Spacer()
                    Button("Shop") {
                        showingShop.toggle()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 2))
                .padding(.horizontal)

                // Inventory Grid
                if viewModel.user.inventory.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("Your inventory is empty.")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Earn gold by completing habits!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            ForEach(viewModel.user.inventory) { item in
                                ItemCard(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Inventory")
            .sheet(isPresented: $showingShop) {
                ShopView(viewModel: viewModel)
            }
        }
    }
}

struct ItemCard: View {
    let item: Item

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: item.icon)
                    .font(.title)
                    .foregroundColor(.blue)
            }

            Text(item.name)
                .font(.headline)

            Text(item.description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 15).fill(Color(.systemBackground)).shadow(radius: 2))
    }
}

struct ShopView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: UserViewModel

    var body: some View {
        NavigationView {
            List(viewModel.shopItems) { item in
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: item.icon)
                            .font(.headline)
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                        Text(item.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        viewModel.buyItem(item)
                    }, label: {
                        HStack {
                            Image(systemName: "banknote.fill")
                                .font(.caption)
                            Text("\(item.price)")
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(viewModel.user.gold >= item.price ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    })
                    .disabled(viewModel.user.gold < item.price)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Adventurer's Shop")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    InventoryView(viewModel: .preview)
}
