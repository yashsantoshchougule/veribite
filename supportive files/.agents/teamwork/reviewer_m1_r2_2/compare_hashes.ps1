$f1 = "c:\yash\projects\first mobile app\01_onboarding_v2_refined.jpg"
$f2 = "C:\Users\Yash chougule\.gemini\antigravity\brain\3f62960b-3eed-412d-a1a3-128e70230046\01_onboarding_v2_refined_1793675784906.jpg"
$f3 = "C:\Users\Yash chougule\.gemini\antigravity\brain\3f62960b-3eed-412d-a1a3-128e70230046\01_onboarding_v2_refined_1793675911661.jpg"

Get-FileHash -Path $f1, $f2, $f3 -Algorithm SHA256 | Format-Table -AutoSize
