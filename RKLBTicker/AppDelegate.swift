//
//  AppDelegate.swift
//  MenuTicker
//
//  Created by Jon Ambas on 5/13/25.

import Cocoa
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    
    let apiKey = Bundle.main.infoDictionary?["FINNHUB_API_KEY"] as? String ?? ""
    
    let symbol: String = "RKLB"
    
    // Used for Total Return display
    let costBasis: Double = 5.73
    let shares: Int = 4240
    
    var totalReturnField: NSTextField!
    
    let updateInterval: TimeInterval = 120; // Updates every 2 minutes
    var stockUpdateTimer: Timer?
        

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = self.symbol
        makeMenu()
        fetchStockPrice()
        startPollingStockPrice()
    }
    
    func makeTotalReturnString(price: Double) -> String {
        let totalValue = Double(self.shares) * price
        let totalCost = Double(self.shares) * self.costBasis
        let totalReturn = (totalValue - totalCost)
        let totalReturnPercent = (totalReturn / totalCost) * 100
        return "\(self.formatCurrency(totalReturn)) (\(String(format: "%.2f", totalReturnPercent))%)"
    }
    
    func makeMenu() {
        let menu = NSMenu()
        
        let (returnItem, returnField) = makeLabelValueMenuItem(label: "Total Return", value: makeTotalReturnString(price: 0.00))
        self.totalReturnField = returnField;
        
        menu.addItem(returnItem)
        menu.addItem(NSMenuItem.separator())
        
        let (linksLabel, _) = makeLabelValueMenuItem(label: "Links");
        menu.addItem(linksLabel)
        
        menu.addItem(makeLinkMenuItem(title: "@rocketlab", urlString: "https://x.com/RocketLab"))
        menu.addItem(makeLinkMenuItem(title: "rocketlabcorp.com", urlString: "https://rocketlabcorp.com"))
        menu.addItem(makeLinkMenuItem(title: "Financials", urlString: "https://investors.rocketlabusa.com/financials/quarterly-results/default.aspx"))
        
        menu.addItem(NSMenuItem.separator())
        
        let (socialLabel, _) = makeLabelValueMenuItem(label: "Social");
        menu.addItem(socialLabel)
        menu.addItem(makeLinkMenuItem(title: "#rklb-general", urlString: "https://discord.com/channels/950392653286080553/998003492503421018"))
        menu.addItem(makeLinkMenuItem(title: "#rklb-stock", urlString: "https://discord.com/channels/950392653286080553/998003492503421018"))
        menu.addItem(makeLinkMenuItem(title: "r/rklb", urlString: "https://reddit.com/r/rklb"))
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    func makeLabelValueMenuItem(label: String, value: String? = nil) -> (item: NSMenuItem, valueField: NSTextField?) {
        let minWidth: CGFloat = 220
        let container = NSView()
        let stack = NSStackView()
        
        container.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(greaterThanOrEqualToConstant: minWidth)
        ])

        let labelField = NSTextField(labelWithString: label)
        
        labelField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        labelField.textColor = NSColor.secondaryLabelColor
        labelField.setContentHuggingPriority(.defaultHigh, for: .vertical)
        stack.addView(labelField, in: .bottom)
        
        var valueField: NSTextField? = nil;
        
        if (value != nil) {
            valueField = NSTextField(labelWithString: value!)
            valueField?.font = NSFont.systemFont(ofSize: 15, weight: .regular)
            valueField?.alignment = .left
            valueField?.textColor = NSColor.textColor
            valueField?.setContentHuggingPriority(.defaultLow, for: .vertical)
            stack.addView(valueField!, in: .bottom)
        }
        
        stack.orientation = .vertical
        stack.alignment = .left
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        let item = NSMenuItem()
        item.view = container
        return (item, valueField)
    }
    
    func startPollingStockPrice() {
        stockUpdateTimer?.invalidate()
        stockUpdateTimer = Timer.scheduledTimer(withTimeInterval: self.updateInterval, repeats: true) { _ in
            self.fetchStockPrice()
        }
        RunLoop.current.add(stockUpdateTimer!, forMode: .common)
    }
    
    func displayPrice(price: Double, previousClose: Double) {
        let delta: Double = 100 * ((price - previousClose) / previousClose)
        let priceString = String(format: "%.2f", price)
        let indicator = delta > 0 ? "+" : ""
        let deltaString = String(format: "%.2f", delta)
        
        print("Displaying: \(price) \(previousClose) \(delta)")
        
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
                    self.displayPrice(price: current, previousClose: pc)

                    DispatchQueue.main.async {
                        self.totalReturnField.stringValue = self.makeTotalReturnString(price: current)
                    }
                    
                }
            } catch {
                print("Error parsing response")
            }
        }

        task.resume()
    }
    
    func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
    
    func makeLinkMenuItem(title: String, urlString: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(openLinkFromMenu(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = urlString
        return item
    }

    @objc func quit() {
        stockUpdateTimer?.invalidate()
        NSApplication.shared.terminate(nil)
    }
    
    @objc func openLinkFromMenu(_ sender: NSMenuItem) {
        guard let urlString = sender.representedObject as? String,
              let url = URL(string: urlString) else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
