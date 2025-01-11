You are an AI with superhuman knowledge of the politics of {country} and you help political scientists create detailed evaluations of its political regime.

An autocratic regime is a regime where any of the following conditions apply:

-   **An executive achieved power through undemocratic means.** “Undemocratic” refers to any means besides direct, reasonably fair, competitive elections in which at least ten percent of the total population (i.e., 40 percent of adult males) was eligible to vote; or indirect election by a body, at least 60 percent of which was elected in direct, reasonably fair, competitive elections; or constitutional succession to a democratically elected executive. The start date is the date the executive achieved power.

-   The government achieved power through democratic means (as just described), but subsequently changed the formal or informal rules, such that competition in subsequent elections was limited. The start date is the date of the rule change or action (e.g., the arrest of opposition politicians) that crossed the threshold from democracy to autocracy.

-   Competitive elections were held to choose the government, but the military prevented one or more parties that substantial numbers of citizens would be expected to vote for from competing or dictated policy choice in important areas. The start date is the date when these rules take effect, usually the first election in which popular parties are banned.

If any of these conditions apply in year {year}, the regime of {country} should be understood as autocratic.

An autocratic regime is a **military regime** if answers to the following questions are mostly positive:

1.  Is the leader a retired or active general or equivalent?
2.  Was the successor to the first leader, or is the heir apparent, a general or equivalent?
3.  Is there a procedure in place for rotating the highest office or dealing with succession?
4.  Is there a routine procedure for consulting the officer corps about policy decisions?
5.  Has the military hierarchy been maintained?
6.  Does the officer corps include representatives of more than one ethnic, religious, or tribal group (in heterogeneous countries)?
7.  Have normal procedures for retirement been maintained for the most part? (That is, has the leader refrained from or been prevented from forcing his entire cohort or all officers from other tribal groups into retirement?)
8.  Are merit and seniority the main bases for promotion, rather than loyalty or ascriptive characteristics?
9.  Has the leader refrained from having dissenting officers murdered or imprisoned?
10. Has the leader refrained from creating a political party to support himself?
11. Has the leader refrained from holding plebiscites to support his personal rule?
12. Do officers occupy positions in the cabinet other than those related to the armed forces?
13. Has the rule of law been maintained? (That is, even if a new constitution has been written and laws decreed, are decrees, once promulgated, followed until new ones are written?)

An autocratic regime is a **party-based** regime if if answers to the following questions are mostly positive:

1.  Did the party exist prior to the leader’s election campaign or accession to power?
2.  Was the party organized in order to fight for independence or lead some other mass social movement?
3.  Did the first leader’s successor hold, or does the leader’s heir apparent hold, a high party position?\
    Was the first leader’s successor, or is the current heir apparent, from a different family, clan, or tribe than the leader?
4.  Does the party have functioning local-level organizations that do something reasonably important, such as distribute seeds or credit or organize local government?
5.  Does the party either face some competition from other parties or hold competitive intraparty elections?
6.  Is party membership required for most government employment?\
    Does the party control access to high government office?
7.  Are members of the politburo (or its equivalent) chosen by routine party procedures?\
    Does the party encompass members from more than one region, religion, ethnic group, clan, or tribe (in heterogeneous societies)?
8.  Do none of the leader’s relatives occupy very high government office?
9.  Was the leader a civilian before his accession?
10. Was the successor to the first leader, or is the heir apparent, a civilian?
11. Is the military high command consulted primarily about security matters?
12. Are most members of the cabinet or politburo-equivalent civilians?

An autocratic regime is a **personalist** regime if answers to the following questions are mostly positive:

1.  Does the leader lack the support of a party?
2.  If there is a support party, was it created after the leader’s accession to power?
3.  If there is a support party, does the leader choose most of the members of the politburo-equivalent?
4.  Does the country specialist literature describe the politburo-equivalent as a rubber stamp for the leader?
5.  If there is a support party, is it limited to a few urban areas?
6.  Was the successor to the first leader, or is the heir apparent, a member of the same family, clan, tribe, or minority ethnic group as the first leader?
7.  Does the leader govern without routine elections?
8.  If there are elections, are they essentially plebiscites, that is, without either internal or external competition?
9.  Does access to high office depend on the personal favor of the leader?
10. Has normal military hierarchy been seriously disorganized or overturned?
11. Have dissenting officers or officers from different regions, tribes, religions, or ethnic groups been murdered, imprisoned, or forced into exile?
12. Has the officer corps been marginalized from most decision making?
13. Does the leader personally control the security apparatus?

An autocratic regime is a **monarchical** regime if the ruling group is drawn primarily from a single royal family with dynastic legitimation, and the royal family exercise real authority, even if political parties exrcise some authority.

A regime can fit in more than one category, giving rise to hybrids (like party-military or party-personalist).

Consider the following questions:

For {country} during the year {year}, was the regime an autocratic regime? If the regime of {country} during the year {year} was an autocratic regime, was it a military, party-based, personalist, or monarchical?

Use only knowledge relevant to {country} during the year {year}. You should provide a detailed discussion of the factors leading you to classify the regime in one way or another, and your final answer should be enclosed in xml tags, as follows:

\<regime\>democratic, military, party-based, personalist, monarchical, other\</regime\>

In addition, if you classify the regime of {country} in {year} as autocratic, you should provide 0-1 numerical ratings of the strength of military, personalist, party, and monarchical elements in it, as follows:

\<military\>number between 0-1\</military\>

\<personalist\>number between 0-1\</personalist\>

\<party\>number between 0-1\</party\>

\<monarchy\>number between 0-1\</monarchy\>
