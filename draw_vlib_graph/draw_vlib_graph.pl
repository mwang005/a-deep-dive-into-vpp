###############################################################################
### Draw vlib graph with Graphviz
###############################################################################
### Usage:
### # perl ./draw_vlib_graph.pl <./show_vlib_graph.txt>
### 
### Time usage
### real    1m27.273s
### user    1m27.070s
### sys     0m0.267s
### 
###############################################################################
### Author  : Michael WANG
### Date    : Jul. 28, 2016
### Version : 0.1.0
###
### ChangeLogs:
###   @Sep. 23, 2017  v0.1.1 by Michael: aligned to vpp v17.07-release
###   @Jul. 28, 2016  v0.1.0 by Michael: Baselined
###   @Jul. 21, 2016  v0.0.1 by Michael: Created
###############################################################################
#!/usr/bin/perl

my $VLIB_GRAPH_TXT = "";
my $DOT_TMP = "dot.tmp";
my $DOT_CFG = "vlib_graph.dot";

### check input arguments
if(defined($ARGV[0])) {
    $VLIB_GRAPH_TXT = $ARGV[0];
} else {
    die "ERR: missing $VLIB_GRAPH_TXT file!\n";
}

### open "show vlib graph" output text file
open(TXT, "$VLIB_GRAPH_TXT") or die("Could not open file:$!.\n");
open(DOT_TMP, ">$DOT_TMP") or die("Could not create file:$!.\n");

#print "digraph vlib_graph { \n";

=cut
skip head line, looks like

           Name                      Next                    Previous
=cut
my $head_line = <TXT>;

my $name = "";
my $next = "";
my $prev = "";

my $name_len = 0;
my $next_len = 0;
my $prev_len = 0;

my $curr_node = "";
my $next_node = "";
my $prev_node = "";

while (my $line = <TXT>) {
    chomp($line);

    $next = "";
    $prev = "";
    $next_len = 0;
    $prev_len = 0;

    ### each node is separated by a blank line
    if ($line ne "") {
        #print "LINE: $line\n";

=cut
the output format of 'show vlib graph'

get the sub-string if the node name presented 
at the place with fixed offset 1, 40 and 66


           Name                      Next                    Previous
<etc>        |                         |                         |
arp-input    |                  error-drop [0]                l2-fwd          
             |               interface-output [1]            l2-flood         
             |                         |              ethernet-input-not-l2  
             |                         |                ethernet-input-type   
             |                         |                  ethernet-input
                                                                 | 
                                                                 | 
1......................................40........................66
<etc>
=cut
        ### get each field if presented, at least one character 
        ### should be there 
        $name = substr($line, 1, 1);  # name of current node
        $next = substr($line, 40, 1); # name of Next node
        $prev = substr($line, 66, 1); # name of Previous node

        ### strip space
        $name =~ s/(^\s+|\s+$)//g;
        $next =~ s/(^\s+|\s+$)//g;
        $prev =~ s/(^\s+|\s+$)//g;
        #print "substr: $name $next $prev\n";
        
        ### get field length; if presented, the len > 0
        $name_len = length($name);
        $next_len = length($next);
        $prev_len = length($prev);
        #print "length: $name_len $next_len $prev_len\n";

        ### reset
        $next_node = "";
        $prev_node = "";

        $line =~ s/(\[\d+\])//g;   # delete string looks like '[0]','[1]', etc
        $line =~ s/(^\s+|\s+$)//g; # strip heading&tailing space

        ### first line for this node(current node name presented on this line)
        if ($name_len > 0) { 
            if ($next_len > 0 && $prev_len > 0) {
                ($curr_node, $next_node, $prev_node) = split(/\s+/, $line);
                
                #print "case 1: curr=$curr_node next=$next_node prev=$prev_node\n";
                print DOT_TMP "\"$prev_node\" -> \"$curr_node\"\n";
                print DOT_TMP "\"$curr_node\" -> \"$next_node\"\n";
            } elsif ($next_len > 0 && $prev_len == 0) {
                ($curr_node, $next_node) = split(/\s+/, $line);
                    
                #print "case 2: $curr_node $next_node $prev_node\n";
                print DOT_TMP "\"$curr_node\" -> \"$next_node\"\n";
            } elsif ($next_len == 0 && $prev_len > 0) {
                ($curr_node, $prev_node) = split(/\s+/, $line);
                
                #print "case 3: $curr_node $next_node $prev_node\n";
                print DOT_TMP "\"$prev_node\" -> \"$curr_node\"\n";
            } elsif ($next_len == 0 && $prev_len == 0) {
                $curr_node = $line;

                #print "case 4: $curr_node $next_node $prev_node\n";
                print DOT_TMP "\"$curr_node\" -> \"$curr_node\"\n";

                print DOT_TMP "\"$curr_node\" [color=grey, style=filled]\n";
            }
        } elsif ($name_len == 0) { # second/following line for this node
            if ($next_len > 0 && $prev_len > 0) {
                ($next_node, $prev_node) = split(/\s+/, $line);

                #print "case 21: $curr_node $next_node $prev_node\n";
                print DOT_TMP "\"$prev_node\" -> \"$curr_node\"\n";
                print DOT_TMP "\"$curr_node\" -> \"$next_node\"\n";
            } elsif ($next_len > 0 && $prev_len == 0) {
                $next_node = $line;
                $prev_node = "";

                #print "case 22: $curr_node $next_node $prev_node\n";
                print DOT_TMP "\"$curr_node\" -> \"$next_node\"\n"; 
            } elsif ($next_len == 0 && $prev_len > 0) {
                $next_node = "";
                $prev_node = $line;

                #print "case 23: $curr_node $next_node $prev_node\n";
                print DOT_TMP "\"$prev_node\" -> \"$curr_node\"\n";
            }
        }
    } elsif ($line eq "") {
        ### reset
        $curr_node = "";
    }
}

#print "}\n";

close DOT;
close INPUT;

###############################################################################
### post process
###############################################################################
### sort and delete duplicated node connection
`echo "digraph vlib_graph_nodes { " > $DOT_CFG`;
`cat $DOT_TMP | sort -u >> $DOT_CFG && rm -f $DOT_TMP`;

### To label traced nodes manually
###
### TODO:
### It will be extracted from "show trace" automatically 
`echo '"dpdk-input" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"ip4-input-no-checksum" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"ip4-lookup" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"ip4-local" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"ip4-icmp-input" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"ip4-icmp-echo-request" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"ip4-rewrite-local" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"TenGigabitEthernet89/0/0-output" [color=blue, style=filled]' >> $DOT_CFG`;
`echo '"TenGigabitEthernet89/0/0-tx" [color=blue, style=filled]' >> $DOT_CFG`;

`echo "}" >> $DOT_CFG`;


### create pictures
my $SVG = "vlib_graph.svg";
my $PDF = "vlib_graph.pdf";
my $PNG = "vlib_graph.png";

`rm -f $SVG $PDF $PNG`;

`dot $DOT_CFG -Tsvg -o $SVG`;
`dot $DOT_CFG -Tpdf -o $PDF`;

### perl ./draw_vlib_graph.pl ./show_vlib_graph.txt 
### dot: graph is too large for cairo-renderer bitmaps. Scaling by 0.990778 to fit
### 
### Why?
### Cairo's maximum bitmap size is 32767x32767 pixels
`dot $DOT_CFG -Tpng -o $PNG`;

