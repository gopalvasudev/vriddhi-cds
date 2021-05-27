mp = 5
startrule = 2
numrules = 10
rulerange = range(startrule, startrule + numrules)
rf = [i for i in rulerange for n in range(0,mp)]

print(rulerange)
print(rf)