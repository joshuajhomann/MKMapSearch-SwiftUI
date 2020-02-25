//
//  ContentView.swift
//  test
//
//  Created by Joshua Homann on 2/24/20.
//  Copyright © 2020 com.josh. All rights reserved.
//

import SwiftUI
import Combine
import MapKit

final class Model: ObservableObject {
  @Published private (set) var items: [MKMapItem] = []
  @Published var selectedItems: Set<MKMapItem> = []
  let term = CurrentValueSubject<String, Never>("")
  private var subscriptions: Set<AnyCancellable> = []
  init() {
    term
      .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
      .removeDuplicates()
      .map { term -> AnyPublisher<[MKMapItem], Never> in
        guard !term.isEmpty else {
          return Just([]).eraseToAnyPublisher()
        }
        return Future<[MKMapItem], Never> { promise in
          let searchRequest = MKLocalSearch.Request()
          searchRequest.naturalLanguageQuery = term
          MKLocalSearch(request: searchRequest).start { response, _ in
            promise(.success(response?.mapItems ?? []))
          }
        }
        .eraseToAnyPublisher()
    }
    .switchToLatest()
    .receive(on: RunLoop.main)
    .assign(to: \.items, on: self)
    .store(in: &subscriptions)

    $items
      .map { _ in Set<MKMapItem>() }
      .assign(to: \.selectedItems, on: self)
      .store(in: &subscriptions)
  }

  func copy() -> Void {
    UIPasteboard.general.string = """
    name, phone, url, thoroughfare, subThoroughfare, locality, subLocality, administrativeArea, subAdministrativeArea, postalCode, isoCountryCode, country, latitude, longitude
    """
    + items.filter(selectedItems.contains(_:)).reduce(into: "") { total, item in
      total +=
      """
      \n\(item.name ?? ""), \(item.phoneNumber ?? ""), \(item.url?.absoluteString ?? ""), \(item.placemark.thoroughfare ?? ""), \(item.placemark.subThoroughfare ?? ""), \(item.placemark.locality ?? ""), \(item.placemark.subLocality ?? ""), \(item.placemark.administrativeArea ?? ""), \(item.placemark.subAdministrativeArea ?? ""), \(item.placemark.postalCode ?? ""), \(item.placemark.isoCountryCode ?? ""), \(item.placemark.country ?? ""), \(item.placemark.coordinate.latitude), \(item.placemark.coordinate.longitude)
      """
    }
  }
}
struct Table: View {
  @ObservedObject var model: Model
  var body: some View {
    VStack {
      Button("Copy", action: { self.model.copy() }).padding()
      TextField("Search...", text: .init(get: {self.model.term.value}, set: model.term.send(_:))).padding()
      List(model.items, id: \.name) { item in
        VStack(alignment: .leading) {
          Text(item.name ?? "").font(.headline)
          Text([item.phoneNumber, item.url?.absoluteString].compactMap{$0}.joined(separator: "\n")).font(.body)
          Text(item.placemark.title ?? "")
        }.onTapGesture {
          if self.model.selectedItems.contains(item) {
            self.model.selectedItems.remove(item)
          } else {
            self.model.selectedItems.insert(item)
          }
        }
        .background(self.model.selectedItems.contains(item) ? Color.accentColor : Color.white)
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Table.init(model: .init())
  }
}
