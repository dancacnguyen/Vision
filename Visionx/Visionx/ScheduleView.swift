//
//  ScheduleView.swift
//  Visionx
//
//  Created by Danca Nguyen on 4/25/25.
//
import SwiftUI

struct ScheduleView: View {
    // Removed userText as it's not needed here anymore
    @State private var scheduleItems: [ScheduleItem] = []
    @State private var isPresentingEditView: Bool = false
    @State private var selectedItemToEdit: ScheduleItem? = nil
    
    var body: some View {
        NavigationView { // Embed in NavigationView for potential navigation to edit view later
            VStack {
                Text("User Schedule")
                    .font(.title2)
                    .padding()

                if scheduleItems.isEmpty {
                    Text("Nothing is added, go add something.")
                        .foregroundColor(.gray)
                } else {
                    List {
                        ForEach(scheduleItems) { item in
                                                    Button {
                                                        selectedItemToEdit = item
                                                        isPresentingEditView = true
                                                    } label: {
                                                        Text("\(item.event_name) on \(dayOfWeekString(from: item.day_of_week)) from \(item.startTimeString) to \(item.endTimeString)")
                                                    }
                                                    .swipeActions {
                                                        Button(role: .destructive) {
                                                            deleteScheduleItem(at: IndexSet(integer: scheduleItems.firstIndex(where: { $0.id == item.id })!))
                                                        } label: {
                                                            Label("Delete", systemImage: "trash")
                                                        }
                                                    }
                                                }
                                            }
                    .sheet(item: $selectedItemToEdit) { item in
                        EditScheduleItemView(scheduleItem: item, onScheduleItemUpdated: { updatedItem in
                            // Handle the updated item returned from the edit view
                            if let index = scheduleItems.firstIndex(where: { $0.id == updatedItem.id }) {
                                scheduleItems[index] = updatedItem                                               }
                                                })
                                            }
                                        }

                                        Spacer()

                Button("Modify Schedule (Future)") {
                    print("Modify schedule tapped")
                }
                .padding()
            }
            .navigationTitle("Weekly Plans")
            .onAppear {
                fetchScheduleFromDjango()
            }
        }
    }

    func fetchScheduleFromDjango() {
        guard let url = URL(string: "http://localhost:8000/api/ai/get_schedule/") else {
            print("Error: Invalid schedule URL")
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching schedule: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Schedule Response Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 200 {
                        if let data = data {
                            print("Raw JSON Response: \(String(data: data, encoding: .utf8) ?? "Could not decode data")") // Add this line for debugging
                            do {
                                let decoder = JSONDecoder()
                                self.scheduleItems = try decoder.decode([ScheduleItem].self, from: data)
                                print("Fetched schedule items: \(self.scheduleItems)")
                            } catch {
                                print("Error decoding schedule JSON: \(error)")
                            }
                        }
                    }
                }
            }
        }.resume()
    }

    func deleteScheduleItem(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let itemToDelete = scheduleItems[index]

        scheduleItems.remove(atOffsets: offsets)

        guard let csrfURL = URL(string: "http://localhost:8000/api/api/get_csrf_token/") else {
            print("Error: Invalid CSRF URL for delete")
            return
        }

        URLSession.shared.dataTask(with: csrfURL) { csrfData, csrfResponse, csrfError in
            if let csrfError = csrfError {
                print("Error fetching CSRF token for delete: \(csrfError.localizedDescription)")
                // Optionally, re-insert the deleted item
                return
            }

            if let csrfResponse = csrfResponse as? HTTPURLResponse {
                print("CSRF Response Status Code (Delete): \(csrfResponse.statusCode)")
            }

            if let csrfData = csrfData {
                do {
                    if let json = try JSONSerialization.jsonObject(with: csrfData, options: []) as? [String: String],
                       let csrfToken = json["csrf_token"] {
                        print("CSRF Token (Delete): \(csrfToken)")
                        self.sendDeleteRequest(itemToDelete: itemToDelete, csrfToken: csrfToken)
                    } else {
                        print("Error: Failed to decode CSRF JSON for delete or missing token")
                        // Optionally, re-insert the deleted item
                    }
                } catch {
                    print("Error decoding CSRF JSON for delete: \(error)")
                    // Optionally, re-insert the deleted item
                }
            }
        }.resume()
    }

    func sendDeleteRequest(itemToDelete: ScheduleItem, csrfToken: String) {
        guard let url = URL(string: "http://localhost:8000/api/ai/delete_schedule/\(itemToDelete.id)/") else {
            print("Error: Invalid delete URL: \(itemToDelete.id)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue(csrfToken, forHTTPHeaderField: "X-CSRFToken") // Add the CSRF token header

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error sending delete request: \(error.localizedDescription)")
                    // Optionally, handle re-insertion
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    print("Delete Response Status Code: \(httpResponse.statusCode)")
                    if httpResponse.statusCode == 204 {
                        print("Schedule item deleted successfully on server.")
                        // No need to do anything further in the UI as we already removed it optimistically
                    } else {
                        print("Error: Failed to delete item on the server. Status code: \(httpResponse.statusCode)")
                        // Optionally, re-fetch the schedule or re-insert the item
                        self.fetchScheduleFromDjango()
                    }
                }
            }
        }.resume()
    }

    // Helper function to convert day_of_week integer to string
    func dayOfWeekString(from dayOfWeek: Int) -> String {
        let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        if dayOfWeek >= 0 && dayOfWeek < days.count {
            return days[dayOfWeek]
        }
        return ""
    }
}

// Conform to Decodable to parse the JSON response
struct ScheduleItem: Identifiable, Decodable, Hashable {
    let id: Int
    let event_name: String
    let start_time: String
    let end_time: String
    let day_of_week: Int
    
    // Helper properties to make display easier
    var startTimeString: String {
        return formatTime(start_time)
    }
    
    var endTimeString: String {
        return formatTime(end_time)
    }
    
    // Simple time formatting function
    func formatTime(_ timeString: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss" // Expecting the format from Django
        
        if let date = dateFormatter.date(from: timeString) {
            dateFormatter.dateFormat = "h:mm a" // Format to display without seconds
            return dateFormatter.string(from: date)
        } else {
            // If parsing with seconds fails, try parsing without seconds (HH:mm)
            dateFormatter.dateFormat = "HH:mm"
            if let dateWithoutSeconds = dateFormatter.date(from: timeString) {
                dateFormatter.dateFormat = "h:mm a"
                return dateFormatter.string(from: dateWithoutSeconds)
            }
        }
        return timeString // Return the original string if parsing fails entirely
    }
}
    
    struct ScheduleView_Previews: PreviewProvider {
        static var previews: some View {
            ScheduleView()
        }
    }
