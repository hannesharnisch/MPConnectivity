//
//  MCHost.swift
//  
//
//  Created by Hannes Harnisch on 04.05.20.
//

import Foundation
import MultipeerConnectivity

public class MCHost:NSObject,MCSessionDelegate,MCNearbyServiceAdvertiserDelegate{
    var mcSession:MCSession!
    var mcAdvertiserAssistent:MCNearbyServiceAdvertiser!;
    var me:MCPeerID
    var deviceName:String
    var name = ""
    public var delegate:MCHostDelegate!
    var SERVICE_TYPE:String
    
    var connections = [MCConnection](){
        didSet{
            let peers = MCConnection.getPeers(connections: connections)
            if self.delegate != nil{
                delegate.didUpdate(Connections: peers)
            }
        }
    }
    var invitations = [DiscoveredPeer](){
        didSet{
            let peers = DiscoveredPeer.getPeers(peers: invitations)
            if self.delegate != nil{
                delegate.didUpdate(Invitations: peers)
            }
        }
    }
    public init(SERVICE_TYPE:String,deviceName:String) {
        self.SERVICE_TYPE = SERVICE_TYPE
        self.deviceName = deviceName
        self.me = MCPeerID(displayName: deviceName)
        super.init()
    }
    deinit {
        mcAdvertiserAssistent.stopAdvertisingPeer()
        self.mcSession.disconnect()
        self.mcSession = nil
    }
    public func start(name:String){
        print("START HOST")
        self.name = name
        self.me = MCPeerID(displayName: "\(name)-\(self.deviceName)")
        mcSession = MCSession(peer: self.me, securityIdentity: nil, encryptionPreference: .required);
        mcSession.delegate = self;
        self.mcAdvertiserAssistent = MCNearbyServiceAdvertiser(peer: self.me, discoveryInfo: nil, serviceType: self.SERVICE_TYPE)
        mcAdvertiserAssistent.delegate = self
        mcAdvertiserAssistent.startAdvertisingPeer()
    }
    public func stop(){
        print("STOP HOST")
        mcAdvertiserAssistent.stopAdvertisingPeer()
        self.mcSession.disconnect()
        connections = []
        invitations = []
    }
    public func disconnectPeer(peer:String) ->Bool{
        print("Disconnect: \(peer)")
        return self.send(data: "exit".data(using: .utf8)!, to: .withName(names: [peer]))
    }
    public func connection(accept:Bool,peer:MCPeerID){
        let peer = invitations.filter { (invit) -> Bool in
            return invit.peerId == peer
        }
        print(peer[0].peerId.displayName)
        peer[0].invitationHandler!(accept,mcSession)
        if !accept{
            self.invitations.removeAll { (peerid) -> Bool in
                return peerid == peer[0]
            }
        }
    }
    public func send(data:Data,to:MCPeerOptions) ->Bool{
        do{
            switch to{
            case .all:
                print("SENDING")
                try self.mcSession.send(data, toPeers: MCConnection.getPeerIDs(from: nil, connections: self.connections), with: .reliable)
            case .withName(let names):
                try self.mcSession.send(data, toPeers: MCConnection.getPeerIDs(from: names, connections: self.connections), with: .reliable)
            default:
                return false
            }
            return true
        }catch(_){
            return false
        }
    }
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected:
            let con = self.connections.first { (con) -> Bool in
                return con.peerId == peerID
            }
            if con == nil{
                self.connections.append(MCConnection(peerId: peerID, mcSession: self.mcSession))
            }else{
                con!.status = .connected
            }
            self.invitations.removeAll { (discovered) -> Bool in
                return discovered.peerId == peerID
            }
            if delegate != nil{
                self.delegate.newConnection(from: peerID)
            }
        case .connecting:
            print("connecting")
        default:
            print("Dis \(peerID.displayName)")
            self.connections.removeAll { (connection) -> Bool in
                return connection.peerId == peerID
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let string = String(data: data, encoding: .utf8){
            print(string)
            if string == "keepAlive"{
                /*let con = self.connections.first { (connection) -> Bool in
                    return connection.peerId == peerID
                }
                con!.status = .keepAlive*/
            }else if string == "dis"{
                self.connections.removeAll { (con) -> Bool in
                    return con.peerId == peerID
                }
            }
        }
        
        if delegate != nil{
            self.delegate.didRecieve(data: data, from: peerID)
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("INVITATION")
        if (self.invitations.firstIndex(where: { (discovered) -> Bool in
            return discovered.peerId == peerID
        }) == nil){
            print(peerID.displayName)
            self.invitations.append(DiscoveredPeer(peerId: peerID, invitationHandler: invitationHandler))
        }
    }
}
public struct DiscoveredPeer:Equatable{
    public static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        return lhs.peerId == rhs.peerId
    }
    public var id = UUID()
    public var peerId:MCPeerID
    public var invitationHandler:((Bool, MCSession?) -> Void)?
    public static func getPeers(peers:[DiscoveredPeer]) ->[MCPeerID]{
        var peerids:[MCPeerID] = []
        for peer in peers{
            peerids.append(peer.peerId)
        }
        return peerids
    }
}
public enum MCPeerOptions{
    case all
    case withName(names:[String])
    case host
}
public protocol MCHostDelegate {
    func didUpdate(Invitations to:[MCPeerID])
    func didUpdate(Connections to:[MCPeerID])
    func didRecieve(data:Data,from:MCPeerID)
    func newConnection(from:MCPeerID)
}
