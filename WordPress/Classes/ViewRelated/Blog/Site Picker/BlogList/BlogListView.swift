import SwiftUI
import DesignSystem

struct BlogListView: View {
    private enum Constants {
        static let imageDiameter: CGFloat = 40
    }

    struct Site {
        let title: String
        let domain: String
        let imageURL: URL?
    }

    @Binding private var isEditing: Bool
    @Binding private var pinnedDomains: Set<String>
    private let sites: [Site]

    init(sites: [Site], pinnedDomains: Binding<Set<String>>, isEditing: Binding<Bool>) {
        self.sites = sites
        self._pinnedDomains = pinnedDomains
        self._isEditing = isEditing
    }
    
    var body: some View {
        List {
            pinnedSection
            unPinnedSection
        }
//        .scrollIndicators(.hidden)
        .listStyle(.grouped)
        .background(Color.DS.Background.primary)
//        .scrollContentBackground(.hidden)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .style(.bodyLarge(.emphasized))
            .foregroundStyle(Color.DS.Foreground.primary)
            .listRowSeparator(.hidden)
    }

    @ViewBuilder
    private var pinnedSection: some View {
        let pinnedSites = BlogListReducer.pinnedSites(
            allSites: sites,
            pinnedDomains: pinnedDomains
        )
        if !pinnedSites.isEmpty {
            Section {
                ForEach(
                    pinnedSites,
                    id: \.domain) { site in
                        siteHStack(
                            site: site
                        )
                    }
            } header: {
                sectionHeader(
                    title: "Pinned sites"
                )
            }
        }
    }

    @ViewBuilder
    private var unPinnedSection: some View {
        let unPinnedSites = BlogListReducer.unPinnedSites(
            allSites: sites,
            pinnedDomains: pinnedDomains
        )
        if !unPinnedSites.isEmpty {
            Section {
                ForEach(
                    unPinnedSites,
                    id: \.domain) { site in
                        siteHStack(
                            site: site
                        )
                    }
            } header: {
                sectionHeader(
                    title: "All sites"
                )
            }
        }
    }

    private func siteHStack(site: Site) -> some View {
        HStack(spacing: 0) {
            AvatarsView(style: .single(site.imageURL))
                .padding(.leading, Length.Padding.double)
                .padding(.trailing, Length.Padding.split)

            textsVStack(title: site.title, domain: site.domain)

            Spacer()

            if isEditing {
                pinIcon(
                    domain: site.domain
                )
                .padding(.trailing, Length.Padding.double)
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(
            .init(
                top: Length.Padding.single,
                leading: 0,
                bottom: Length.Padding.single,
                trailing: 0
            )
        )
    }

    private func textsVStack(title: String, domain: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .style(.bodySmall(.regular))
                .foregroundStyle(Color.DS.Foreground.primary)
                .layoutPriority(1)
                .lineLimit(2)

            Text(domain)
                .style(.bodySmall(.regular))
                .foregroundStyle(Color.DS.Foreground.secondary)
                .layoutPriority(2)
                .lineLimit(1)
                .padding(.top, Length.Padding.half)
        }
    }

    private func pinIcon(domain: String) -> some View {
        Button(action: {
            withAnimation(.interactiveSpring) {
                pinnedDomains = pinnedDomains.symmetricDifference([domain])
            }
        }, label: {
            if pinnedDomains.contains(domain) {
                Image(systemName: "pin.fill")
                    .imageScale(.small)
                    .foregroundStyle(Color.DS.Background.brand(isJetpack: true))
            } else {
                Image(systemName: "pin")
                    .imageScale(.small)
                    .foregroundStyle(Color.DS.Foreground.secondary)
            }
        })
    }
}

#Preview {
    BlogListView(
        sites: [
            .init(title: "Clay Chronicles",
                  domain: "claychronicles.com",
                  imageURL: URL(string: "https://picsum.photos/40/40")!
                 ),
            .init(title: "Culinary Wanderlust",
                  domain: "culinarywanderlust.wordpress.com",
                  imageURL: URL(string: "https://picsum.photos/40/40")!
                 )
        ], 
        pinnedDomains: .constant([]), 
        isEditing: .constant(true)
    )
}
