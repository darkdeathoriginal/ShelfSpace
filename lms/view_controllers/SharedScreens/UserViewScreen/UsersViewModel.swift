//
//  UsersViewModel.swift
//  lms
//
//  Created by Diptayan Jash on 25/04/25.
//
import Foundation
import SwiftUI
import Combine

class UsersViewModel: ObservableObject {
    @Published var selectedSegment = 0
    @Published var users: [User] = [] // Your User model list

    // Alert states
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var alertType: AlertType = .success

    enum AlertType {
        case success
        case error
    }

    // Computed properties - Filter using the User model's is_active flag
    var activeLibrarians: [User] {
        users.filter { $0.role == .librarian && ($0.is_active != nil) }
    }
    var activeMembers: [User] {
        users.filter { $0.role == .member && ($0.is_active != nil) }
    }

    // State for Add User Sheet
    @Published var isShowingAddUserSheet = false
    @Published var roleToAdd: UserRole?
    @Published var newUserInputName: String = ""
    @Published var newUserInputEmail: String = ""
    @Published var newUserInputLibraryId: String = ""
    @Published var newUserInputImage: UIImage? = nil

    // State for Deactivation/Activation Confirmation
    @Published var userToToggle: User?
    @Published var showToggleConfirmation = false
    @Published var toggleActionIsActivate = false

    // --- Functions ---

    func prepareToAddUser(role: UserRole) {
        roleToAdd = role
        resetUserInputForm()
        isShowingAddUserSheet = true
    }

    func addUser() {
        guard let role = roleToAdd,
              !newUserInputName.isEmpty,
              isValidEmail(newUserInputEmail),
              !newUserInputLibraryId.isEmpty
        else {
             print("Validation failed for adding user.")
             return
         }
        let profileImageData = newUserInputImage?.jpegData(compressionQuality: 0.8)
        let newUser = User(
            id: UUID(),
            email: newUserInputEmail,
            role: role,
            name: newUserInputName,
            is_active: true, // New users are active
            library_id: newUserInputLibraryId,
            profileImage: profileImageData
        )
        users.append(newUser)
        resetUserInputForm()
        isShowingAddUserSheet = false
        objectWillChange.send()
    }

    func toggleUserActiveStatus(_ user: User) {
        userToToggle = user
        toggleActionIsActivate = !(user.is_active ?? false)
        showToggleConfirmation = true
    }

    func confirmToggleUserStatus() {
        guard let user = userToToggle else { return }
        let userId = user.id
        let newActiveStatus = toggleActionIsActivate
        // Optimistically update UI
        if let index = users.firstIndex(where: { $0.id == userId }) {
            users[index].is_active = newActiveStatus
            objectWillChange.send()
        }
        // Call API to update the user status in background
        updateUserActiveStatus(userId: userId, isActive: newActiveStatus) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    let action = newActiveStatus ? "activated" : "deactivated"
                    self?.showAlert(
                        title: "Success",
                        message: "User has been \(action) successfully.",
                        type: .success
                    )
                    // Refresh the user list
                    self?.fetchUsersoflibrary()
                    // Force UI update
                    self?.objectWillChange.send()
                case .failure(let error):
                    // Revert the UI change if API call fails
                    if let index = self?.users.firstIndex(where: { $0.id == userId }) {
                        self?.users[index].is_active = !newActiveStatus
                        self?.objectWillChange.send()
                    }
                    self?.showAlert(
                        title: "Error",
                        message: "Failed to update user status: \(error.localizedDescription)",
                        type: .error
                    )
                }
                self?.userToToggle = nil
                self?.showToggleConfirmation = false
            }
        }
    }

    func updateUserActiveStatus(userId: UUID, isActive: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        Task {
            do {
                let token = try KeychainManager.shared.getToken()
                
                // Construct the URL with the user's ID
                guard let url = URL(string: "https://www.anwinsharon.com/lms/api/v1/users/\(userId)") else {
                    throw URLError(.badURL)
                }
                
                // Prepare request
                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
                // Find the user to get their name and role
                guard let user = users.first(where: { $0.id == userId }) else {
                    throw NSError(domain: "UsersViewModel",
                                  code: 404,
                                  userInfo: [NSLocalizedDescriptionKey: "User not found in local data"])
                }
                
                // Construct the request body - only send the fields we want to update
                let requestBody: [String: Any] = [
                    "name": user.name,
                    "is_active": isActive,
                    "role": user.role.rawValue.lowercased() // Convert enum to lowercase string
                ]
                
                // Convert to JSON using JSONUtility
                let jsonData = try JSONUtility.shared.encodeFromDictionary(requestBody)
                request.httpBody = jsonData
                
                // Make the request
                let (data, response) = try await URLSession.shared.data(for: request)
                
                // Debug response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("API Response for status update: \(jsonString)")
                }
                
                // Check status code
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NSError(domain: "UsersViewModel",
                                code: 500,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
                }
                
                guard 200..<300 ~= httpResponse.statusCode else {
                    // Try to decode error response
                    if let errorResponse = try? JSONUtility.shared.decode(APIErrorResponse.self, from: data) {
                        throw NSError(domain: "UsersViewModel",
                                    code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: errorResponse.error.message])
                    } else {
                        let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
                        throw NSError(domain: "UsersViewModel",
                                    code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: errorMsg])
                    }
                }
                
                // Success
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("Error updating user status:")
                error.logDetails()
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // Add this struct to handle API error responses
    struct APIErrorResponse: Codable {
        let success: Bool
        let error: ErrorDetail
    }

    struct ErrorDetail: Codable {
        let message: String
    }

    func resetUserInputForm() {
        newUserInputName = ""
        newUserInputEmail = ""
        newUserInputLibraryId = ""
        newUserInputImage = nil
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }

     func uiImage(from data: Data?) -> UIImage? {
         guard let data = data else { return nil }
         return UIImage(data: data)
     }

    // MARK: - User Management
    func fetchUsersoflibrary() {
        fetchUsers { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fetchedUsers):
                    print("Successfully fetched \(fetchedUsers.count) users")
                    self?.users = fetchedUsers
                    // Force UI update
                    self?.objectWillChange.send()
                case .failure(let error):
                    self?.showAlert(title: "Error", message: "Failed to fetch users: \(error.localizedDescription)", type: .error)
                }
            }
        }
    }

    func showAlert(title: String, message: String, type: AlertType) {
        alertTitle = title
        alertMessage = message
        alertType = type
        showAlert = true
    }
}
