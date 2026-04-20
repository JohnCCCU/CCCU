import tkinter as tk
from pyVim.connect import SmartConnect
import ssl

class LoginWindow:
    def __init__(self):
        self.root = tk.Tk()
        self.root.title("vCenter Login")

        tk.Label(self.root, text="vCenter:").grid(row=0, column=0)
        tk.Label(self.root, text="Username:").grid(row=1, column=0)
        tk.Label(self.root, text="Password:").grid(row=2, column=0)

        self.vcenter = tk.Entry(self.root)
        self.user = tk.Entry(self.root)
        self.pwd = tk.Entry(self.root, show="*")

        self.vcenter.grid(row=0, column=1)
        self.user.grid(row=1, column=1)
        self.pwd.grid(row=2, column=1)

        tk.Button(self.root, text="Connect", command=self.submit).grid(row=3, column=0, columnspan=2)

        self.values = None
        self.root.mainloop()

    def submit(self):
        self.values = (
            self.vcenter.get(),
            self.user.get(),
            self.pwd.get()
        )
        self.root.destroy()

vcenter, user, pwd = LoginWindow().values

context = ssl._create_unverified_context()
si = SmartConnect(host=vcenter, user=user, pwd=pwd, sslContext=context)
content = si.RetrieveContent()
print("Connected to:", vcenter)
