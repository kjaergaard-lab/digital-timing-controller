clear;
tc = TimingController;

for nn=1:tc.NUM_CHANNELS
    tc.channels(nn).default = 0;
end
tc.channels(1).add(1e-3,1);
tc.channels(2).add(1e-3,1);
tc.channels(1).add(10e-3,0);
tc.channels(2).add(5e-3,0);
tc.channels(2).add(10e-3,1);
tc.channels(1).add(5e-3,0);
tc.channels(1).add(6e-3,1);

