#!/usr/bin/env python

# https://www.youtube.com/watch?v=2uQ2BSzDvXs
# Twiddle - Artificial Intelligence for Robotics

from subprocess import call
from numpy.linalg import norm 
from numpy import loadtxt
import pdb

from shutil import copyfile



def run(p):
    # ./main pid 5 -0.01 -0.10 -.0007 pid-data.txt  
# PID:
#    call(['./main','pid','3',str(p[0]),str(p[1]),str(p[2]),'pid-data.txt'])
# P:
#    call(['./main','pid','3',str(p[0]),'0','0','pid-data.txt'])
# PI:
#    call(['./main','pid','3',str(p[0]),str(p[1]),'0','pid-data.txt'])

# pid-fwd22-arggains:
    call(['./pid-fwd22-arggains',str(p[0]),str(p[1]),str(p[2])])
    copyfile('./pid-fwd.txt', './pid-fwd-bak.txt')
    errvec = loadtxt('pid-fwd-bak.txt',skiprows=1,usecols=[6])  # 0-indexed. col 6 = error.
    return norm(errvec) # can experiment with various p-norms here norm(errvec,3.5)


if __name__ == "__main__":

    print("Welcome!")
#    pdb.set_trace()

    # Idea: wiggle each param in turn, first one direction,
    # then the other. If it's better, 

# PID:
#    p = [-0.016, -0.16, -0.0004] # decent initial PID gains
#    dp = [.01,.01,.0001] # initial twiddle magnitude

# P: 
#    p = [-0.08 ] # decent initial PID gains
#    dp = [.005] # initial twiddle magnitude

# PI:
    p = [-0.083, -.056, -.0006 ] # decent initial PID gains
    dp = [.01,.01,.0002] # initial twiddle magnitude

    best_err = run(p)

    niter = 0;

    # While 
    while sum(dp)>.000001:
        print('===========================niter,dp,sum(dp):',niter,dp,sum(dp))
        for i in range(len(p)):      # For each param,
            print('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~gains:',p)
            p[i] += dp[i]            # Try increasing it.
            err = run(p)
            print('-----------------------------err:',err)
            if err < best_err:       # If bigger p[i] is better,
                best_err = err
                dp[i] *= 1.1         # try probing more next time.
            else:                    # Else, try smaller p[i].
                p[i] -= 2*dp[i]      # (2 bc gotta reverse it)
                err = run(p)
                print('........................err:',err)
                if err < best_err:   # If smaller p[i] is better,
                    best_err = err
                    dp[i] *= 1.1     # try probing more next time.
                else:                # Else, 
                    p[i] += dp[i]    # reset p[i] to what it was,
                    dp[i] *= 0.9     # and twiddle less next time.
            
