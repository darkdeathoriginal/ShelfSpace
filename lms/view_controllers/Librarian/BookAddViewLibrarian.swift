import SwiftUI
import DotLottie

struct BookAddViewLibrarian: View {
    @StateObject private var homePaginationManager = BookPaginationManager()
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var currentStep: BookAddStep = .isbn
    @State private var showImagePicker = false
    @State private var showBarcodeScanner = false
    @State private var bookData = BookData()
    @State private var focusedField: BookFieldType?
    @State private var isLoading = false
    var onSave: (BookModel) -> Void
    
    enum BookAddStep {
        case isbn
        case details
    }
    
    enum BookFieldType {
        case isbn
        case title
        case description
        case publisher
        case language
        case author
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ReusableBackground(colorScheme: colorScheme)
                
                switch currentStep {
                case .isbn:
                    ISBNInputStep(
                        bookData: $bookData,
                        showBarcodeScanner: $showBarcodeScanner,
                        onContinue: {
                            withAnimation(.easeInOut) {
                                currentStep = .details
                            }
                        }, onScanComplete: {
                            withAnimation(.easeInOut) {
                                currentStep = .details
                            }
                        }
                    )
                case .details:
                    BookDetailsStep(
                        bookData: $bookData,
                        showImagePicker: $showImagePicker,
                        isLoading: $isLoading,
                        onSave: {
                            Task {
                                isLoading = true
                                defer { isLoading = false }
                                do {
                                    let bookModel = BookModel(
                                        id: UUID(),
                                        libraryId: bookData.libraryId ?? UUID(),
                                        title: bookData.bookTitle,
                                        isbn: bookData.isbn,
                                        description: bookData.description,
                                        totalCopies: bookData.totalCopies,
                                        availableCopies: bookData.availableCopies,
                                        reservedCopies: bookData.reservedCopies,
                                        authorIds: bookData.authorIds,
                                        authorNames: bookData.authorNames,
                                        genreIds: bookData.genreIds,
                                        genreNames: bookData.genreNames,
                                        publishedDate: bookData.publishedDate,
                                        addedOn: Date(),
                                        updatedAt: Date(),
                                        coverImageUrl: bookData.bookCoverUrl,
                                        coverImageData: bookData.bookCover?.jpegData(compressionQuality: 0.8)
                                    )
                                    let createdBook = try await createBook(book: bookModel)
                                    print("✅ Book saved to database with ID: \(createdBook.id)")
                                    onSave(createdBook)
                                    dismiss()
                                } catch {
                                    print("❌ Error saving book: \(error)")
                                    // Optionally show error UI
                                }
                            }
                        }
                    )
                }
            }
            .navigationBarTitle(currentStep == .isbn ? "Add Book" : "Book Details", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    if currentStep == .details {
                        withAnimation(.easeInOut) {
                            currentStep = .isbn
                        }
                    } else {
                        dismiss()
                    }
                }) {
                    Text(currentStep == .details ? "Back" : "Cancel")
                        .foregroundColor(currentStep == .details ? .blue : .red)
                },
                trailing: currentStep == .details ?
                    Button(action: {
                        saveBook()
                        dismiss()
                    }) {
                        Text("Save")
                            .fontWeight(.medium)
                    } : nil
            )
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $bookData.bookCover)
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(scannedCode: $bookData.isbn){_ in
                }
            }
            .onTapGesture {
                focusedField = nil
            }
        }
    }
    
    private func saveBook() {
        // Generate UUIDs for authors
        let authorIds = bookData.authorNames.map { _ in UUID() }
        
        // Convert UIImage to Data if available
        let coverImageData = bookData.bookCover?.jpegData(compressionQuality: 0.8)
        
        // TODO: In a real app, you would upload the image to cloud storage here
        // and get back the URL. For now, we'll just use a placeholder URL if we have an image
        let coverImageUrl = coverImageData != nil ? "https://placeholder-url.com/book-cover.jpg" : nil
        
        let newBook = BookModel(
            id: UUID(),
            libraryId: bookData.libraryId ?? UUID(), // Replace with real libraryId if you have it
            title: bookData.bookTitle,
            isbn: bookData.isbn,
            description: bookData.description,
            totalCopies: bookData.totalCopies,
            availableCopies: bookData.availableCopies,
            reservedCopies: bookData.reservedCopies,
            authorIds: bookData.authorIds,
            authorNames: bookData.authorNames,
            genreIds: bookData.genreIds,
            genreNames: bookData.genreNames,
            publishedDate: bookData.publishedDate,
            addedOn: Date(),
            updatedAt: Date(),
            coverImageUrl: coverImageUrl,
            coverImageData: coverImageData
        )

        
        // Call the onSave closure with the new book
        onSave(newBook)
    }
}

#Preview {
    BookAddViewLibrarian(onSave: { _ in })
}



struct bookViewLibrarian: View {
    
    @StateObject private var homePaginationManager = BookPaginationManager()
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var books: [BookModel] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: BookGenre = .all
    @State private var showingAddBookSheet = false
    @State private var bookToEdit: BookModel?
    @State private var showAddBook = false
    @State private var showImagePicker = false

    @State private var bookData = BookData()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false

    var filteredBooks: [BookModel] {
        var result = books

        if selectedCategory != .all {
            result = result.filter { $0.genreNames?.contains(selectedCategory.rawValue) == true }

        }


        if !searchText.isEmpty {
            result = result.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
//                book.authorNames!.joined(separator: " ").localizedCaseInsensitiveContains(searchText)
//                ||
                    (book.isbn ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }
    var body: some View {
        NavigationView {
            ZStack {
                ReusableBackground(colorScheme: colorScheme)

                ScrollView {
                    VStack(spacing: 16) {
                        // Search bar (scrolls with content)
                        SearchBar(searchText: $searchText, colorScheme: colorScheme)

                        // Category filter (scrolls with content)
                        CategoryFilterView(
                            selectedCategory: $selectedCategory,
                            colorScheme: colorScheme
                        )

                        // Loading or Book List (scrolls below search & filter)
                        if isLoading {
                            LoadingAnimationView(colorScheme: colorScheme)

                        } else {
                            if books.isEmpty {
                                EmptyBookListView(colorScheme: colorScheme)
                            } else {
                                BookList(
                                    books: filteredBooks,
                                    colorScheme: colorScheme,
                                    onEdit: { book in
                                        bookToEdit = book
                                        showingAddBookSheet = true
                                    },
                                    onDelete: deleteBook
                                )
                            }
                        }
                    }
                    .padding(.top)
                }
                .refreshable {
                    await loadBooks()
                }
            }
            .navigationTitle("Books")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        bookToEdit = nil
                        showingAddBookSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(Color.primary(for: colorScheme))
                    }
                }
            }
            .sheet(isPresented: $showingAddBookSheet) {
                if let bookToEdit = bookToEdit {
                    Text("Edit Book")
                        .font(.headline)
                        .padding()
                } else {
                    BookAddViewLibrarian(onSave: { newBook in
                        addNewBook(newBook)
                    })
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .task {
                await loadBooks()
            }
        }
    }
    
    private func loadBooks() async {
            isLoading = true
        fetchBooks(manager: homePaginationManager) { result in
                defer { isLoading = false }

                switch result {
                case let .success(fetchedBooks):
                    self.books = fetchedBooks
                    for book in fetchedBooks where book.coverImageUrl != nil {
                        self.preloadBookCover(for: book)
                    }
                case let .failure(error):
                    self.errorMessage = error.localizedDescription
                    self.showError = true
                }
            }
        }
    private func preloadBookCover(for book: BookModel) {
        guard let urlString = book.coverImageUrl,
              let url = URL(string: urlString) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            // Log for debugging
            if let error = error {
                print("Error preloading image for \(book.title): \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                print("HTTP Error \(httpResponse.statusCode) preloading image for \(book.title)")
                return
            }
            
            if let data = data, UIImage(data: data) != nil {
                print("Successfully preloaded image for \(book.title)")
                // In a real application, you might want to store this in a cache
            } else {
                print("Invalid image data for \(book.title)")
            }
        }.resume()
    }

    private func deleteBook(_ book: BookModel) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            withAnimation {
                books.remove(at: index)
            }
        }
    }

    private func addNewBook(_ book: BookModel) {
        withAnimation {
            books.append(book)
        }
    }

    private func updateBook(_ updatedBook: BookModel) {
        if let index = books.firstIndex(where: { $0.id == updatedBook.id }) {
            withAnimation {
                books[index] = updatedBook
            }
        }
    }
}
struct loadingAnimationView: View {
    var colorScheme: ColorScheme
    
    var body: some View {
        VStack {
            DotLottieAnimation(
                fileName: "policy",
                config: AnimationConfig(
                    autoplay: true,
                    loop: true,
                    mode: .bounce,
                    speed: 1.0
                )
            )
            .view()
            .frame(height: 600)
        }
    }
}
// Empty state view for when there are no books
struct emptyBookListView: View {
    var colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(Color.primary(for: colorScheme).opacity(0.7))
                .padding(.bottom, 10)

            Text("No books found")
                .font(.title2)
                .fontWeight(.medium)

            Text("Add new books using the + button or pull down to refresh")
                .font(.subheadline)
                .foregroundColor(Color.text(for: colorScheme).opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Subviews

struct searchBar: View {
    @Binding var searchText: String
    var colorScheme: ColorScheme

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color.primary(for: colorScheme).opacity(0.8))
                .padding(.leading, 12)

            TextField("Search books...", text: $searchText)
                .padding(.vertical, 12)
                .font(.system(size: 16, design: .rounded))

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color.primary(for: colorScheme).opacity(0.9))
                }
                .padding(.trailing, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(hex: ColorConstants.darkBackground) : Color(hex: ColorConstants.lightBackground))
        )
        .padding(.horizontal)
    }
}

struct categoryFilterView: View {
    @Binding var selectedCategory: BookGenre
    var colorScheme: ColorScheme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(BookGenre.allCases, id: \.self) { category in
                    CategoryButton(
                        category: category,
                        selectedCategory: $selectedCategory,
                        colorScheme: colorScheme
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

struct categoryButton: View {
    var category: BookGenre
    @Binding var selectedCategory: BookGenre
    var colorScheme: ColorScheme

    var body: some View {
        Button(action: {
            withAnimation(.spring()) {
                selectedCategory = category
            }
        }) {
            Text(category.rawValue)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(selectedCategory == category ?
                            (colorScheme == .dark ? Color.primary(for: colorScheme).opacity(0.3) : Color.secondary(for: colorScheme).opacity(0.15)) :
                            (colorScheme == .dark ? Color(hex: ColorConstants.darkBackground1) : Color(hex: ColorConstants.lightBackground1)))
                )
                .overlay(
                    Capsule()
                        .stroke(selectedCategory == category ? Color.background(for: colorScheme).opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .foregroundColor(selectedCategory == category ?
            (colorScheme == .dark ? .white : Color.secondary(for: colorScheme)) :
            Color.text(for: colorScheme).opacity(0.7))
    }
}

struct bookList: View {
    var books: [BookModel]
    var colorScheme: ColorScheme
    var onEdit: (BookModel) -> Void
    var onDelete: (BookModel) -> Void

    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(books) { book in
                BookCell(
                    book: book,
                    onEdit: { onEdit(book) },
                    onDelete: { onDelete(book) }
                )
            }
        }
        .padding(.horizontal)
    }
}

struct bookCell: View {
    var book: BookModel
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        ZStack {
            BooksCell(book: book)

            // Invisible button covering the entire cell to handle taps
            Rectangle()
                .foregroundColor(.clear)
                .contentShape(Rectangle())
                .onTapGesture {
                    // Handle tap action if needed
                }
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// Scroll offset preference key to track scrolling
struct scrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

//struct BookAddViewLibrarian_Previews: PreviewProvider {
//    static var previews: some View {
//        BookAddViewLibrarian()
//            .preferredColorScheme(.light)
//
//        BookAddViewLibrarian()
//            .preferredColorScheme(.dark)
//    }
//}
