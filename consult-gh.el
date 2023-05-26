(defgroup consult-gh nil
  "Consulting GitHub CLI"
  :group 'convenience
  :group 'minibuffer
  :group 'consult
  :group 'magit
  :prefix "consult-gh-")

(defcustom consult-gh-category 'consult-gh
  "Category symbol for the `consult-gh' package."
  :group 'consult-gh
  :type 'symbol)

(defcustom consult-gh--default-maxnum 30
  "Maximum number of output for gh list operations normally passed top \"--limit\" in the command line."
  :group 'consult-gh
  :type 'integer)

(defcustom consult-gh-crm-separator "[\s]"
  "Separator for multiple selections with completing-read-multiple. for more info see `crm-separator'."
  :group 'consult-gh
  :type 'string)

(defcustom consult-gh-default-orgs-list (list)
  "List of default github orgs for `consult-gh' package."
  :group 'consult-gh
  :type 'listp)

(defcustom consult-gh-default-clone-directory nil
  "Default directory to clone github repos in for `consult-gh' package."
  :group 'consult-gh
  :type 'string)

(defvar consult-gh--repos-history nil
  "History variable for repos used in `consult-gh-search-repos'.")

(defvar consult-gh--org-history nil
  "History variable for orgs used in  `consult-gh-orgs' .")

(defvar consult-gh--known-orgs-list nil
  "List of previously visited orgs for `consult-gh'.")


(defvar consult-gh--known-repos-list nil
  "List of previously visited orgs for `consult-gh'.")

(defface consult-gh-default-face
  `((t :foreground "#00A8B0" :inherit default)) "teal used for default list items")
(defface consult-gh-visibility-face
  `((t :foreground "#DC80BA" :inherit default)) "pink used for repo visibility")
(defface consult-gh-userface
  `((t :foreground "#FDD78B" :inherit default)) "light yellow used for users")

(defun consult-gh--call-process (&rest args)
  "Run \"gh\" with args and return output if no errors. If there are erros pass them to *Messages*."
  (if (executable-find "gh")
      (with-temp-buffer
        (let ((out (list (apply 'call-process "gh" nil (current-buffer) nil args)
                         (buffer-string))))
          (if (= (car out) 0)
              (cadr out)
            (progn
              (message (cadr out))
              nil)
            )))
    (progn
      (message (propertize "\"gh\" is not found on this system" 'face 'warning))
      nil)
    ))

(defun consult-gh--get-repos-of-org (org)
"Get a list of repos of \"organization\" and format each as a text with properties to pass to consult."
  (let* ((maxnum (format "%s" consult-gh--default-maxnum))
         (repolist  (or (consult-gh--call-process "repo" "list" org "--limit" maxnum) ""))
         (repos (mapcar (lambda (s) (string-split s "\t")) (split-string repolist "\n"))))
    (remove "" (mapcar (lambda (src) (propertize (car src) ':user (car (string-split (car src) "\/")) ':description (cadr src) ':visibility (cadr (cdr src)) ':version (cadr (cdr (cdr src))))) repos)))
    )

(defun consult-gh--get-search-repos (repo)
"Search for repos with \"gh search repos\" and return a list of items each formatted with properties to pass to consult."
  (let* ((maxnum (format "%s" consult-gh--default-maxnum))
         (repolist  (or (consult-gh--call-process "search" "repos" repo "--limit" maxnum) ""))
         (repos (mapcar (lambda (s) (string-split s "\t")) (split-string repolist "\n"))))
    (remove "" (mapcar (lambda (src) (propertize (car src) ':user (car (string-split (car src) "\/")) ':description (cadr src) ':visibility (cadr (cdr src)) ':version (cadr (cdr (cdr src))))) repos)))
    )

(defun consult-gh--output-cleanup (string)
"REmove non UTF-8 characters if any in the string. This is used in "
  (string-join
   (delq nil (mapcar (lambda (ch) (encode-coding-char ch 'utf-8 'unicode))
                     string))))

(defun consult-gh--repos-action ()
"Default action to run on selected itesm in `consult-gh'."
(lambda (cand)
  (browse-url (concat "https://github.com/" (substring cand)))
))

(defun consult-gh--repos-group (cand transform)
"Group the list of item in `consult-gh' by the name of the user"
  (let ((name (car (string-split (substring cand) "\/"))))
           (if transform (substring cand) name)))

(defun consult-gh--org-narrow (org)
"Create narrowing function for items in `consult-gh' by the first letter of the name of the user/organization."
  (if (stringp org)
    (cons (string-to-char (substring-no-properties org)) (substring-no-properties org))))

(defun consult-gh--search-repo-narrow (repo)
"Create narrowing function for items in `consult-gh' by the first letter of the name of the user/organization."
    (cons (string-to-char (substring-no-properties repo)) (substring-no-properties repo)))

(defun consult-gh--repos-annotate ()
"Annotate each repo in `consult-gh' by user, visibility and date."
(lambda (cand)
  ;; (format "%s" cand)
  (if-let ((user (format "%s" (get-text-property 1 :user cand)))
         (visibility (format "%s" (get-text-property 1 :visibility cand)))
         (date (format "%s" (get-text-property 1 :version cand))))

      (progn
        (setq user (propertize user 'face 'consult-gh-userface)
          visibillity (propertize visibility 'face 'consult-gh-visibility-face)
          date (propertize date 'face 'consult-gh-date-face))
        (format "%s\t%s\t%s" user visibility date)
     )
    nil)
))

(defun consult-gh--make-source-from-org  (org)
"Create a source for consult from the repos of the organization to use in `consult-gh-orgs'."
                  `(:narrow ,(consult-gh--org-narrow org)
                    :category 'consult-gh
                    :items  ,(consult-gh--get-repos-of-org org)
                    :face 'consult-gh-default-face
                    :action ,(consult-gh--repos-action)
                    :annotate ,(consult-gh--repos-annotate)
                    :defualt t
                    :history t
                    ))

(defun consult-gh--make-source-from-search-repo  (repo)
"Create a source for consult from the search results for repo to use in `consult-gh-search-repos'."
                  `(:narrow ,(consult-gh--search-repo-narrow repo)
                    :category 'consult-gh
                    :items  ,(consult-gh--get-search-repos repo)
                    :face 'consult-gh-default-face
                    :action ,(consult-gh--repos-action)
                    :annotate ,(consult-gh--repos-annotate)
                    :default t
                    :history t
                    ))

(defun consult-gh-orgs (orgs)
"Get a list of organizations from the user and provide their repos."
  (interactive
   (let ((crm-separator consult-gh-crm-separator)
         (candidates (or (delete-dups (append consult-gh-default-orgs-list consult-gh--known-orgs-list)) (list))))
   (list (delete-dups (completing-read-multiple "GitHub Org: " candidates nil nil nil 'consult-gh--org-history nil t)))))

  (let ((candidates  (consult--slow-operation "Collecting Repos..."(mapcar #'consult-gh--make-source-from-org orgs))))
    (if (not (member nil (mapcar (lambda (cand) (plist-get cand :items)) candidates)))
      (progn
          (setq consult-gh--known-orgs-list (append consult-gh--known-orgs-list orgs))
          (consult--multi  candidates
                    :require-match t
                    :sort t
                    :group #'consult-gh--repos-group
                    :history 'consult-gh--repos-history
                    :category 'consult-gh
                    ))
      )))

(defun consult-gh-default-repos ()
"Show the repos from default organizaitons."
  (interactive)
(consult-gh-orgs consult-gh-default-orgs-list))

(defun consult-gh-search-repos (repos)
"Get a list of repos from the user and return the results in `consult-gh' menu by runing \"gh search repos\"."
  (interactive
   (let ((crm-separator consult-gh-crm-separator)
         (candidates (or (delete-dups consult-gh--known-repos-list) (list))))
   (list (delete-dups (completing-read-multiple "Repos: " candidates nil nil nil nil nil t)))))
  (let ((candidates  (consult--slow-operation "Collecting Repos..." (mapcar #'consult-gh--make-source-from-search-repo repos))))
    (if (not (member nil (mapcar (lambda (cand) (plist-get cand :items)) candidates)))
      (progn
          (setq consult-gh--known-repos-list (append consult-gh--known-repos-list repos))
          (consult--multi  candidates
                    :require-match t
                    :sort t
                    :group #'consult-gh--repos-group
                    :history 'consult-gh--repos-history
                    :category 'consult-gh
                    ))
      (message (concat "consult-gh: " (propertize "no repositories matched your search!" 'face 'warning))))))

(defun consult-gh--clone-repo (repo targetdir name)
"Clone the repo to targetdir/name directory. It uses \"gh clone repo ...\"."
  (consult-gh--call-process "repo" "clone" (format "%s" repo) (expand-file-name name targetdir)))

(defun consult-gh-clone-repo (&optional repo targetdir name)
  (interactive)
  (let ((repo (read-string "repo: " repo))
        (targetdir (read-directory-name "target directory: " targetdir))
        (name (read-string "name: " name))
        )
  (consult-gh--clone-repo repo targetdir name)
    ))

(provide 'consult-gh)