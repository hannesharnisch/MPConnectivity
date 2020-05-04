//
//  MCClient.swift
//  
//
//  Created by Hannes Harnisch on 04.05.20.
//

import Foundation
import MultipeerConnectivity

public class MCClient:NSObject,MCSessionDelegate,MCNearbyServiceBrowserDelegate{
    var isRunning = false
    var mcSession:MCSession!
    var mcBrowser:MCNearbyServiceBrowser!
    public var delegate:MCClientDelegate!
    var currentHost:MCPeerID!
    var me:MCPeerID
    var deviceName:String
    var name = ""
    var SERVICE_TYPE:String
    var connections = [MCConnection](){
        didSet{
            let peers = MCConnection.getPeers(connections: connections)
            if self.delegate != nil{
                delegate.didUpdate(Connections: peers)
            }
        }
    }
    var discoveredPeers = [DiscoveredPeer](){
        didSet{
            let peers = DiscoveredPeer.getPeers(peers: discoveredPeers)
            if self.delegate != nil{
                delegate.didUpdate(foundPeers: peers)
            }
        }
    }
    public init(SERVICE_TYPE:String,deviceName:String){
        self.SERVICE_TYPE = SERVICE_TYPE
        self.deviceName = deviceName
        self.me = MCPeerID(displayName: deviceName)
        super.init()
        //let notificationCenter = NotificationCenter.default
        //notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.willResignActiveNotification, object: nil)
    }
    @objc func appMovedToBackground(){
        print("KEEP ALIVE")
        if self.isRunning{
            _ = self.send(data: "keepAlive".data(using: .utf8)!, to: .host)
            let con = self.connections.first { (con) -> Bool in
                return con.peerId == self.currentHost
            }
            if con != nil{
                con!.status = .keepAlive
            }
        }
    }
    deinit {
        print("DEINIT")
        if self.currentHost != nil{
            _ = self.send(data: "dis".data(using: .utf8)!, to: .host)
        }
        self.stop()
    }
    func start(name:String){
        self.name = name
        isRunning = true
        print("STARTING CLIENT")
        self.me = MCPeerID(displayName: "\(name)-\(self.deviceName)")
        mcSession = MCSession(peer: self.me, securityIdentity: nil, encryptionPreference: .required);
        mcSession.delegate = self
        mcBrowser = MCNearbyServiceBrowser(peer: self.me, serviceType: SERVICE_TYPE)
        mcBrowser.delegate = self
        mcBrowser.startBrowsingForPeers()
    }
    func stop(){
        isRunning = false
        print("STOPPING CLIENT")
        mcBrowser.stopBrowsingForPeers()
        self.mcSession.disconnect()
        self.mcSession = nil
        connections = []
        self.currentHost = nil
        discoveredPeers = []
        currentHost = nil
    }
    func reset(){
        self.stop()
        self.start(name: name)
    }
    func invite(peer:String)->Bool{
        let peers = discoveredPeers.filter { (discovered) -> Bool in
            return peer == discovered.peerId.displayName
        }
        print("CONNECT TO")
        print(peers[0].peerId.displayName)
        return self.sendRequestToConnect(to: peers[0].peerId)
    }
    func sendRequestToConnect(to:MCPeerID) -> Bool{
        let index = self.discoveredPeers.lastIndex { (discovered) -> Bool in
            return discovered.peerId == to
        }
        if index != nil{
            self.mcBrowser.invitePeer(to, to: mcSession, withContext: nil, timeout: 0)
            self.currentHost = to
            return true
        }else{
            return false
        }
    }
    func send(data:Data,to:MCPeerOptions) ->Bool{
        do{
            switch to{
            case .all:
                try self.mcSession.send(data, toPeers: MCConnection.getPeerIDs(from: nil, connections: self.connections), with: .reliable)
            case .withName(let names):
                try self.mcSession.send(data, toPeers: MCConnection.getPeerIDs(from: names, connections: self.connections), with: .reliable)
            case .host:
                try self.mcSession.send(data, toPeers: [self.currentHost], with: .reliable)
            }
            return true
        }catch(_){
            return false
        }
    }
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            print("Connected")
            self.connections.append(MCConnection(peerId: peerID, mcSession: self.mcSession))
            self.discoveredPeers.removeAll { (discovered) -> Bool in
                return discovered.peerId == peerID
            }
        case .connecting:
            print("connecting")
        default:
            print("Dis \(peerID.displayName)")
            self.connections.removeAll { (connection) -> Bool in
                return connection.peerId == peerID
            }
            if peerID == currentHost {
                self.reset()
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        let text = String(data: data, encoding: .utf8)
        print("DID RECIEVE")
        if text == "exit"{
            print("RESET")
            self.reset()
        }else{
            if self.delegate != nil{
                self.delegate.didRecieve(data: data, from: peerID)
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        let index = self.discoveredPeers.lastIndex { (discoverd) -> Bool in
            return discoverd.peerId.displayName == peerID.displayName
        }
        if index == nil{
                self.discoveredPeers.append(DiscoveredPeer(peerId: peerID))
            print("ADDED PEER \(peerID.displayName)")
            print(DiscoveredPeer.getPeers(peers: discoveredPeers).description)
        }
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        self.discoveredPeers.removeAll { (discovered) -> Bool in
            return discovered.peerId == peerID
        }
    }
    
    
}
public protocol MCClientDelegate {
    func didUpdate(foundPeers to:[MCPeerID])
    func didUpdate(Connections to:[MCPeerID])
    func didRecieve(data:Data,from:MCPeerID)
}
