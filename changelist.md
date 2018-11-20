## policy_wonk Changelist

### 1.0.0.rc.1
* Take a dializer type fix from Tyler Clemens (tielur)
* Can now pass non-plug contexts into policies. (adamzaninovich)

### 1.0.0.rc.0
* Simplification of the policy engine

### 0.2.1
* Relaxed the Elixir version requirement back to 1.3 with OTP 18. Tested via Travis.

### 0.2.0
* Cleaned up warnings generated from Elixir 1.4.0
* Removed Behaviour module from policy.ex and loader.ex definitions. Now using @callbackto
  describe the requireced callbacks

### 0.1.3
* surface errors within a policy instead of swallowing them during call - thanks to Eric Watson
* update to latest ex_doc

### 0.1.2
* fix issues in documentation
* add changelist, since I don't fully remember 0.1.1

### 0.1.0
* First release