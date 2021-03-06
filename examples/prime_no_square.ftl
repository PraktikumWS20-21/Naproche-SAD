[synonym number/-s] [synonym devide/-s]
Signature. A rational number is a notion.

Let s,r,q stand for rational numbers.

Signature. r * q is a rational number.
Axiom. r * q = q * r.
Axiom. r * (q * s) = (r * q) * s.
Axiom. q * s = q * r => s = r.

Signature. A natural number is a rational number.

Let n,m,k denote natural numbers.

Axiom. n * m is a natural number.

Definition. n | q iff there exists k such that k * n = q.

Let n divides m stand for n | m.
Let a divisor of m stand for a natural number that divides m.

Definition. n and m are coprime iff n and m have no common divisor.

Signature. A prime number is a natural number.

Let p denote a prime number.

Axiom. p | n * m => p | n \/ p | m.

Axiom. There exist coprime m,n such that m * q = n.

Let q^2 stand for q * q.

Proposition. q^2 = p for no rational number q.
Proof by contradiction.
Assume the contrary. Take a rational number q such that p = q^2.
Take coprime m,n such that m * q = n. Then p * m^2 = n^2.
Therefore p divides n. Take a natural number k such that n = k * p.
Then p * m^2 = p * (k * n).
Therefore m * m is equal to p * k^2.
Hence p divides m. Contradiction.
qed.
