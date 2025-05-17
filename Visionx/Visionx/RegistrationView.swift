//
//  RegistrationView.swift
//  Visionx
//
//  Created by Danca Nguyen on 3/14/25.
//
import SwiftUI
import UIKit

struct RegistrationView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var email = ""
    @State private var registrationSuccessful = false
    
    var body: some View {
        VStack {
            TextField("Email", text: $email)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            TextField("Username", text: $username)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            SecureField("Password", text: $password)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            SecureField("Confirm Password", text: $confirmPassword)
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
                .padding(.horizontal, 20)
            
            Button(action: {
                register()
            }) {
                Text("Register")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
            NavigationLink(destination: MainView(), isActive: $registrationSuccessful) { // Add NavigationLink
                            EmptyView()
                        }
        }
        .padding()
        .navigationTitle("Register")
    }
    
    func register() {
        guard let url = URL(string: "http://localhost:8000/api/api/register/") else {
            errorMessage = "Invalid URL"
            return
        }
        
        let registrationData: [String: String] = ["username": username, "password": password, "email": "test@example.com"]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: registrationData) else {
            errorMessage = "Failed to encode data"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 1. Get CSRF Token (Assuming you have a function to retrieve it)
        getCsrfToken { csrfToken in
            if let csrfToken = csrfToken {
                // 2. Add X-CSRFToken header
                request.addValue(csrfToken, forHTTPHeaderField: "X-CSRFToken")
                
                request.httpBody = jsonData
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    DispatchQueue.main.async {
                        if let error = error {
                            errorMessage = "Network error: \(error.localizedDescription)"
                            return
                        }
                        
                        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                            errorMessage = "Invalid response from server"
                            return
                        }
                        
                        guard let data = data else {
                            errorMessage = "No data received"
                            return
                        }
                        
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                                print("JSON Response: \(json)")
                                
                                if let success = json["success"] as? Int, success == 1 { // modified line
                                    print("Registration successful!")
                                    registrationSuccessful = true

                                } else if let errorMsg = json["error"] as? String {
                                    errorMessage = errorMsg
                                } else {
                                    errorMessage = "Registration failed"
                                }
                            } else {
                                errorMessage = "Invalid JSON response"
                            }
                        } catch {
                            errorMessage = "Failed to decode JSON"
                        }
                    }
                }.resume()
            } else {
                self.errorMessage = "Failed to get CSRF Token!"
            }
        }
    }
}

func getCsrfToken(completion: @escaping (String?) -> Void) {
    guard let csrfURL = URL(string: "http://localhost:8000/api/api/get_csrf_token/") else {
        completion(nil)
        return
    }

    URLSession.shared.dataTask(with: csrfURL) { data, response, error in
        if let data = data {
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: String],
               let csrfToken = json["csrf_token"] {
                completion(csrfToken)
            } else {
                completion(nil)
            }
        } else {
            completion(nil)
        }
    }.resume()
}

#Preview {
    RegistrationView()
}

