//
//  MCHost.swift
//  
//
//  Created by Hannes Harnisch on 04.05.20.
//

import Foundation
import MultipeerConnectivity

class MCHost:NSObject,MCSessionDelegate,MCNearbyServiceAdvertiserDelegate{
    var mcSession:MCSession!
    var mcAdvertiserAssistent:MCNearbyServiceAdvertiser!;
    var me = MCPeerID(displayName: UIDevice.current.name)
    var name = ""
    var delegate:MCHostDelegate!
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
    init(SERVICE_TYPE:String) {
        self.SERVICE_TYPE = SERVICE_TYPE
        super.init()
    }
    deinit {
        mcAdvertiserAssistent.stopAdvertisingPeer()
        self.mcSession.disconnect()
        self.mcSession = nil
    }
    func start(name:String){
        print("START HOST")
        self.name = name
        self.me = MCPeerID(displayName: "\(name)-\(UIDevice.current.name)")
        mcSession = MCSession(peer: self.me, securityIdentity: nil, encryptionPreference: .required);
        mcSession.delegate = self;
        self.mcAdvertiserAssistent = MCNearbyServiceAdvertiser(peer: self.me, discoveryInfo: nil, serviceType: self.SERVICE_TYPE)
        mcAdvertiserAssistent.delegate = self
        mcAdvertiserAssistent.startAdvertisingPeer()
    }
    func stop(){
        print("STOP HOST")
        mcAdvertiserAssistent.stopAdvertisingPeer()
        self.mcSession.disconnect()
        connections = []
        invitations = []
    }
    func disconnectPeer(peer:String) ->Bool{
        print("Disconnect: \(peer)")
        return self.send(data: "exit".data(using: .utf8)!, to: .withName(names: [peer]))
    }
    func connection(accept:Bool,peer:MCPeerID){
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
    func send(data:Data,to:MCPeerOptions) ->Bool{
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
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
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
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
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
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("INVITATION")
        if (self.invitations.firstIndex(where: { (discovered) -> Bool in
            return discovered.peerId == peerID
        }) == nil){
            print(peerID.displayName)
            self.invitations.append(DiscoveredPeer(peerId: peerID, invitationHandler: invitationHandler))
        }
    }
}
struct DiscoveredPeer:Equatable{
    static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        return lhs.peerId == rhs.peerId
    }
    var id = UUID()
    var peerId:MCPeerID
    var invitationHandler:((Bool, MCSession?) -> Void)?
    static func getPeers(peers:[DiscoveredPeer]) ->[MCPeerID]{
        var peerids:[MCPeerID] = []
        for peer in peers{
            peerids.append(peer.peerId)
        }
        return peerids
    }
}
enum MCPeerOptions{
    case all
    case withName(names:[String])
    case host
}
protocol MCHostDelegate {
    func didUpdate(Invitations to:[MCPeerID])
    func didUpdate(Connections to:[MCPeerID])
    func didRecieve(data:Data,from:MCPeerID)
    func newConnection(from:MCPeerID)
}
