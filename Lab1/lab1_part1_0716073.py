#!/usr/bin/env python3
from mininet.cli import CLI
from mininet.log import setLogLevel
from mininet.net import Mininet
from mininet.topo import Topo

class Part1_Topo(Topo):
    def __init__(self):
        Topo.__init__(self)

        # Add hosts
        h1 = self.addHost('h1')
        h2 = self.addHost('h2')
        h3 = self.addHost('h3')
        h4 = self.addHost('h4')

        # Add switches
        s1 = self.addSwitch('s1', failMode = 'standalone')
        s2 = self.addSwitch('s2', failMode = 'standalone')
        s3 = self.addSwitch('s3', failMode = 'standalone')
        
        # Add links
        self.addLink(s1, h1)
        self.addLink(s1, h2)
        self.addLink(s3, h3)
        self.addLink(s3, h4)
        self.addLink(s2, s1)
        self.addLink(s2, s3)


if __name__ == '__main__':
    setLogLevel('info')
    topo = Part1_Topo()
    net = Mininet(controller = None, topo = topo)

    net.start()
    CLI(net)
    net.stop()

