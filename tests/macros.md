\newcommand{\apply}[2]{#1\!\left(#2\right)}
\newcommand{\Upper}[1]{\apply{O}{#1}}
\newcommand{\Bound}[1]{\apply{\Theta}{#1}}
\newcommand{\Lower}[1]{\apply{\Omega}{#1}}
\newcommand{\CHO}{\text{CH}} <!-- CH Operator -->
\newcommand{\CHP}[1]{\CHO_{#1}} <!-- CH Problem -->
\newcommand{\CH}[1]{\apply{\CHO}{#1}}
\newcommand{\Reduction}[1]{\leq_{#1}}
\newcommand{\ReductionN}{\Reduction{N}}
\newcommand{\As}{\coloneq}
\newcommand{\cardinal}[1]{\left|#1\right|}
\newcommand{\ceil}[1]{\left\lceil#1\right\rceil}
\newcommand{\floor}[1]{\left\lfloor#1\right\rfloor}

\newcommand{\lessAt}[1]{<_{#1}}

\newcommand{\set}[1]{\left\{#1\right\}}
\newcommand{\norm}[1]{\left\|#1\right\|}

\newcommand{\Real}{\mathbb{R}}

\newcommand{\Cell}[1]{\apply{\text{Cell}}{#1}}
\newcommand{\Disk}[2]{\apply{\text{Disk}}{#1, #2}}

\newcommand{\FPVDO}{\text{FPVD}}
\newcommand{\FPVDP}{\FPVDO}
\newcommand{\FPVD}[1]{\apply{\FPVDO}{#1}}

\newcommand{\SortingO}{\text{SORTING}}
\newcommand{\SortingP}{\SortingO}

\newcommand{\TriangulationO}{\text{Triangulation}}
\newcommand{\TriangulationP}{\TriangulationO}
\newcommand{\Triangulation}[1]{\apply{\TriangulationO}{#1}}

\newcommand{\DTO}{\text{DT}}
\newcommand{\DTP}{\DTO}
\newcommand{\DT}[1]{\apply{\DTO}{#1}}

\newcommand{\VDO}{\text{VD}}
\newcommand{\VDP}{\VDO}
\newcommand{\VD}[1]{\apply{\VD}{#1}}

\newcommand{\NNGO}{\text{NNG}}
\newcommand{\NNGP}{\NNGO}
\newcommand{\NNG}[1]{\apply{\NNGO}{#1}}
