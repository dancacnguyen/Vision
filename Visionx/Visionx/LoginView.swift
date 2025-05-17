//
//  LoginView.swift
//  Visionx
//
//  Created by Danca Nguyen on 3/14/25.
//
import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var navigateToMainView = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack { // Or NavigationView
            NavigationLink(destination: MainView(), isActive: $navigateToMainView) {
                EmptyView() // No visible label
            }
            
            VStack {
                TextField("Username", text: $username)
                    .padding()
                SecureField("Password", text: $password)
                    .padding()
                NavigationLink(destination: RegistrationView()) { // This is where the error originates
                    Text("Register")
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                }

                Button("Login") {
                    getCSRFToken { csrfToken in
                        if let csrfToken = csrfToken {
                            login(username: username, password: password, csrfToken: csrfToken)
                        } else {
                            errorMessage = "Failed to get CSRF token."
                        }
                    }
                }
                .padding()

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .padding()
        }
            
    }

    func login(username: String, password: String, csrfToken: String) {
           guard let url = URL(string: "http://localhost:8000/api/api/login/") else { // Changed to localhost
               errorMessage = "Invalid URL"
               return
           }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")

        let parameters: [String: Any] = ["username": username, "password": password]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: parameters)
        } catch {
            print("Error: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Login Error: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Login Invalid Response")
                return
            }

            print("Login Response Status Code: \(httpResponse.statusCode)")

            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Login Response JSON: \(json)")

                    if let token = json["token"] as? String, !token.isEmpty {
                        // Login successful
                        DispatchQueue.main.async {
                            self.navigateToMainView = true
                        }
                    } else {
                        // Login failed
                        DispatchQueue.main.async {
                            self.errorMessage = "Login failed. Invalid token."
                        }
                    }
                } else {
                    print("Login Response Data is Not Valid JSON")
                }
            } else {
                print("Login No Data Received")
            }
        }.resume()
    }

    func getCSRFToken(completion: @escaping (String?) -> Void) {
         guard let url = URL(string: "http://localhost:8000/api/api/get_csrf_token/") else { // Changed to localhost
             completion(nil)
             return
         }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data {
                if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let csrfToken = json["csrf_token"] as? String {
                    completion(csrfToken) // Add this line
                } else {
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }.resume()
    }

}

#Preview {
    LoginView()
}
