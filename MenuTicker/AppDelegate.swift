//
//  AppDelegate.swift
//  MenuTicker
//
//  Created by Jon Ambas on 5/13/25.
//

import Cocoa
import Foundation



class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!    
    let apiKey = Bundle.main.infoDictionary?["FINNHUB_API_KEY"] as? String ?? ""
    let symbol: String = "RKLB"
    var pc: Double = 0.0;
    var status: String = "Closed";

    // var webSocketTask: URLSessionWebSocketTask?
    
    // Timers
    var stockUpdateTimer: Timer?,
        marketOpenTimer: Timer?,
        marketCloseTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = self.symbol
        
        print(apiKey)
        
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(handleWakeFromSleep),
//            name: NSWorkspace.didWakeNotification,
//            object: nil
//        )
        
        self.fetchStockPrice()
        
        let menu = NSMenu()
        
        menu.addItem(makeLinkMenuItem(title: "RKLB on Yahoo Finance", urlString: "https://finance.yahoo.com/quote/\(self.symbol)"))
        menu.addItem(makeLinkMenuItem(title: "rocketlabusa.com", urlString: "https://rocketlabusa.com"))
        menu.addItem(makeLinkMenuItem(title: "#rklb-general", urlString: "https://discord.com/channels/950392653286080553/998003492503421018"))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
        
//        scheduleMarketOpenTrigger()
    }
    
    
    
    func startPollingStockPrice() {
        print("✅ Market open — starting stock polling.")
        
        stockUpdateTimer?.invalidate()
        stockUpdateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
            self.fetchStockPrice()
        }
        RunLoop.current.add(stockUpdateTimer!, forMode: .common)
        
        self.status = "Open";
        
        // Schedules stop
//        scheduleMarketCloseTrigger()
    }
    
//    func stopPollingStockPrice() {
//        print("🔕 Market closed — stopping polling.")
//        stockUpdateTimer?.invalidate()
//        stockUpdateTimer = nil
//        
//        self.status = "Closed";
//    }
    
//    func scheduleMarketCloseTrigger() {
//        let calendar = Calendar(identifier: .gregorian)
//        let now = Date()
//
//        var marketCloseComponents = calendar.dateComponents(in: TimeZone(identifier: "America/New_York")!, from: now)
//        marketCloseComponents.hour = 16
//        marketCloseComponents.minute = 1
//        marketCloseComponents.second = 0
//
//        guard let marketCloseDate = calendar.date(from: marketCloseComponents),
//              marketCloseDate > now else {
//            return
//        }
//
//        let timeUntilClose = marketCloseDate.timeIntervalSince(now)
//        print("⏱ Scheduling market close in \(Int(timeUntilClose)) seconds")
//
//        Timer.scheduledTimer(withTimeInterval: timeUntilClose, repeats: false) { _ in
//            self.stopPollingStockPrice()
//        }
//    }
//    
    func scheduleMarketOpenTrigger() {
        let calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "America/New_York")!
        let now = Date()

        // 1. Build today's 9:30 AM and 4:00 PM ET
        var baseComponents = calendar.dateComponents(in: timeZone, from: now)
        baseComponents.second = 0

        var marketOpenComponents = baseComponents
        marketOpenComponents.hour = 9
        marketOpenComponents.minute = 30

        var marketCloseComponents = baseComponents
        marketCloseComponents.hour = 16
        marketCloseComponents.minute = 0

        guard var marketOpenDate = calendar.date(from: marketOpenComponents),
              let marketCloseDate = calendar.date(from: marketCloseComponents) else {
            return
        }

        // 2. If after 4:00 PM, schedule for tomorrow
        if now >= marketCloseDate {
            marketOpenDate = calendar.date(byAdding: .day, value: 1, to: marketOpenDate)!
        }

        // 3. Skip weekends
        let weekday = calendar.component(.weekday, from: marketOpenDate)
        if weekday == 7 { // Saturday
            marketOpenDate = calendar.date(byAdding: .day, value: 2, to: marketOpenDate)!
            print("📆 Market closed on Saturday. Scheduling for Monday.")
        } else if weekday == 1 { // Sunday
            marketOpenDate = calendar.date(byAdding: .day, value: 1, to: marketOpenDate)!
            print("📆 Market closed on Sunday. Scheduling for Monday.")
        }

        // 4. If now is already within market hours (between 9:30 and 16:00), start polling
        if now >= marketOpenDate && now < marketCloseDate {
            print("✅ Market is open (local time check). Starting polling.")
            self.startPollingStockPrice()
        } else {
            // 5. Otherwise, schedule a timer for the next market open
            let timeUntilOpen = marketOpenDate.timeIntervalSince(now)
            print("⏱ Market is closed. Scheduling open in \(Int(timeUntilOpen)) seconds.")

            marketOpenTimer?.invalidate()
            marketOpenTimer = Timer.scheduledTimer(withTimeInterval: timeUntilOpen, repeats: false) { _ in
                self.startPollingStockPrice()
            }
            RunLoop.current.add(marketOpenTimer!, forMode: .common)
        }
    }
    
    func displayPrice(price: Double) {
        let delta: Double = 100 * ((price - self.pc) / self.pc)
        let priceString = String(format: "%.2f", price)
        let indicator = delta > 0 ? "+" : "–"
        let deltaString = String(format: "%.2f", delta)
        
        print("Displaying: \(price) \(self.pc) \(delta)")
        
        DispatchQueue.main.async {
            self.statusItem?.button?.title =
            "\(self.symbol) · \(priceString) \(indicator)\(deltaString)%"
        }
    }
    
    func fetchStockPrice() {
        print("Fetching price")
        let url = URL(string: "https://finnhub.io/api/v1/quote?symbol=\(symbol)&token=\(apiKey)")!

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error fetching stock: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["c"] as? Double,
                   let pc = json["pc"] as? Double {
                    self.pc = pc
                    self.displayPrice(price: current)
                }
            } catch {
                print("Error parsing response")
            }
        }

        task.resume()
    }

    @objc func quit() {
        marketOpenTimer?.invalidate()
        stockUpdateTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
    
    func makeLinkMenuItem(title: String, urlString: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openLinkFromMenu(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = urlString
        return item
    }
    
    @objc func openLinkFromMenu(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
    
    
}


// connectToWebSocket(symbol: self.symbol)
//        isMarketOpen { isOpen in
//            if isOpen {
//                DispatchQueue.main.async {
//                    self.stockUpdateTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { _ in
//                        self.fetchStockPrice()
//                    }
//                    RunLoop.current.add(self.stockUpdateTimer!, forMode: .common)
//                }
//            } else {
//                 print("Market is closed")
//            }
//        }

//    func connectToWebSocket(symbol: String) {
//
//        let url = URL(string: "wss://ws.finnhub.io?token=\(apiKey)")!
//        webSocketTask = URLSession(configuration: .default).webSocketTask(with: url)
//        webSocketTask?.resume()
//
//        // Subscribe to a symbol
//        print("Subscribing to \(symbol)")
//        let subscribeMessage = [
//            "type": "subscribe",
//            "symbol": self.symbol
//        ]
//
//        if let jsonData = try? JSONSerialization.data(withJSONObject: subscribeMessage) {
//            let message = URLSessionWebSocketTask.Message.data(jsonData)
//            webSocketTask?.send(message) { error in
//                if let error = error {
//                    print("WebSocket send error: \(error)")
//                }
//            }
//        }
//
//        receiveMessages()
//    }
    
//    func receiveMessages() {
//        webSocketTask?.receive { [weak self] result in
//            switch result {
//            case .failure(let error):
//                print("WebSocket receive error: \(error)")
//                self?.reconnect()
//            case .success(let message):
//                switch message {
//                case .data(let data):
//                    self?.handleWebSocketData(data)
//                case .string(let text):
//                    if let data = text.data(using: .utf8) {
//                        self?.handleWebSocketData(data)
//                    }
//                @unknown default:
//                    print("breaking")
//                    break
//                }
//
//                self?.receiveMessages()
//            }
//        }
//    }
    

//    func handleWebSocketData(_ data: Data) {
//        do {
//            // 1. Try decoding top-level JSON
//            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
//                print("✅ Received WebSocket JSON:", json)
//
//                // 2. Check type
//                guard let type = json["type"] as? String, type == "trade" else {
//                    print("❌ Not a trade update")
//                    return
//                }
//
//                // 3. Check data array
//                guard let dataArray = json["data"] as? [[String: Any]], !dataArray.isEmpty else {
//                    print("❌ No trade data in message")
//                    return
//                }
//
//                // 4. Get first trade
//                let trade = dataArray[0]
//                guard let price = trade["p"] as? Double,
//                      let _ = trade["s"] as? String else {
//                    print("❌ Missing 'p' or 's' in trade:", trade)
//                    return
//                }
//
//                // 5. Update UI
//                DispatchQueue.main.async {
//                    self.displayPrice(price: price)
//                }
//
//            } else {
//                print("❌ Failed to cast JSON root as [String: Any]")
//            }
//
//        } catch {
//            print("❌ JSON decode error: \(error)")
//        }
//    }
//    func handleWebSocketData(_ data: Data) {
//
//
//        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//              let type = json["type"] as? String, type == "trade",
//              let dataArray = json["data"] as? [[String: Any]],
//              let trade = dataArray.first,
//              let price = trade["p"] as? Double,
//              let symbol = trade["s"] as? String else {
//            print("canceling")
//            return
//        }
//
//        DispatchQueue.main.async {
//            self.displayPrice(price: price)
//        }
//    }
    
//    func reconnect() {
//        print("reconnect");
//        // Wait 1 second and reconnect
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            self.connectToWebSocket(symbol: self.symbol)
//        }
//    }

//    func isMarketOpen(completion: @escaping (Bool) -> Void) {
//        let url = URL(string: "https://finnhub.io/api/v1/stock/market-status?exchange=US&token=\(apiKey)")!
//
//        let task = URLSession.shared.dataTask(with: url) { data, response, error in
//            guard let data = data, error == nil else {
//                print("Error fetching market open status: \(error?.localizedDescription ?? "Unknown error")")
//                completion(false)
//                return
//            }
//
//            do {
//                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//                   let isOpen = json["isOpen"] as? Bool {
//                    completion(isOpen)
//                } else {
//                    completion(false)
//                }
//            } catch {
//                print("Error parsing response")
//                completion(false)
//            }
//        }
//
//        task.resume()
//    }
