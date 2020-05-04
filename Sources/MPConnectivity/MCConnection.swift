//
//  MCConnection.swift
//  
//
//  Created by Hannes Harnisch on 04.05.20.
//

import Foundation
import MultipeerConnectivity

class MCConnection{
    var peerId:MCPeerID
    var mcSession:MCSession
    var status = MCStatus.connected
    init(peerId:MCPeerID,mcSession:MCSession){
        self.peerId = peerId
        self.mcSession = mcSession
    }
    static func getPeers(connections:[MCConnection]) -> [MCPeerID]{
        var names = [MCPeerID]()
        for connection in connections{
            names.append(connection.peerId)
        }
        return names
    }
    static func getPeerIDs(from names:[String]?,connections:[MCConnection]) -> [MCPeerID]{
        var peers = [MCPeerID]()
        if names != nil{
            for connection in connections{
                if names!.contains(connection.peerId.displayName){
                    peers.append(connection.peerId)
                }
            }
            return peers
        }else{
            for connection in connections{
                peers.append(connection.peerId)
            }
            return peers
        }
    }
    
}
enum MCStatus{
    case connected
    case keepAlive
    case disconnected
}
